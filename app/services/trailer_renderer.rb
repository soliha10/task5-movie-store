require "open3"
require "digest"

class TrailerRenderer
  CACHE_DIRECTORY = Rails.root.join("tmp/trailers")
  FONT_DIRECTORY = Rails.root.join("vendor/fonts")
  FALLBACK_FONT = "Oswald"
  CACHE_KEY_LENGTH = 24
  FRAMES_PER_SECOND = 24
  SAMPLE_RATE = 44_100
  VIDEO_OUTPUT_ARGS = %w[-c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p].freeze
  AUDIO_OUTPUT_ARGS = %w[-c:a aac -b:a 128k].freeze
  AUDIO_FORMAT = "aformat=sample_rates=#{SAMPLE_RATE}:channel_layouts=stereo".freeze
  FFMPEG_TRANSITIONS = {
    "dissolve" => "fade", "fade_in" => "fade", "dip_black" => "fadeblack", "dip_white" => "fadewhite",
    "flash" => "fadewhite", "zoom_blur" => "zoomin", "whip" => "slideleft", "glitch" => "pixelize",
    "light_leak" => "fade", "flicker" => "fadeblack", "cut" => "fade"
  }.freeze
  DEFAULT_FFMPEG_TRANSITION = "fade"
  MINIMUM_OVERLAP = 0.04
  SHOT_PADDING = 0.05
  SOURCE_PADDING = 0.2
  DIM_DELAY = 0.3
  BRIGHTNESS_STRENGTH = 0.4
  TINT_STRENGTH = 1.7
  VIGNETTE_BASE_ANGLE = 0.3
  VIGNETTE_ANGLE_RANGE = 0.5
  GRAIN_STRENGTH = 60
  LETTERBOX_SHARE = 0.11
  FADE_IN_SECONDS = 0.4
  FADE_OUT_SECONDS = 0.5
  TEXT_FADE_IN_SECONDS = 0.5
  TEXT_FADE_OUT_SECONDS = 0.3
  TEXT_MAX_WIDTH_SHARE = 0.84
  TEXT_CHARACTER_WIDTH = 0.7
  MUSIC_FADE_OUT_SECONDS = 1.2

  def initialize(spec)
    @spec = spec.deep_symbolize_keys
    @width, @height = @spec[:size]
  end

  def render
    FileUtils.mkdir_p(CACHE_DIRECTORY)
    output_path = CACHE_DIRECTORY.join("#{Digest::SHA256.hexdigest(@spec.to_json)[0, CACHE_KEY_LENGTH]}.mp4")
    return output_path if File.size?(output_path)

    Dir.mktmpdir do |work_directory|
      @work_directory = work_directory
      draft_path = File.join(work_directory, "trailer.mp4")
      run_ffmpeg(draft_path)
      FileUtils.mv(draft_path, output_path)
    end
    output_path
  end

  private

  def shots = @spec[:shots]
  def duration = @spec[:duration]
  def grade = @spec[:grade]

  def run_ffmpeg(output_path)
    _output, errors, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", *ffmpeg_inputs, "-filter_complex", filter_graph,
      "-map", "[vout]", "-map", "[aout]", *VIDEO_OUTPUT_ARGS, *AUDIO_OUTPUT_ARGS,
      "-movflags", "+faststart", "-t", duration.to_s, output_path
    )
    raise "ffmpeg failed: #{errors.lines.last(5).join}" unless status.success?
  end

  def ffmpeg_inputs
    @input_numbers = {}
    input_paths = []
    shots.each_with_index do |shot, shot_index|
      next unless shot[:type] == "clip"

      @input_numbers[[:shot, shot_index]] = input_paths.size
      input_paths << local_path(shot[:url])
    end
    sounds.each_with_index do |sound, sound_index|
      @input_numbers[[:sound, sound_index]] = input_paths.size
      input_paths << local_path(sound[:url])
    end
    input_paths.flat_map { |path| ["-i", path] }
  end

  def sounds
    @sounds ||= [@spec.dig(:audio, :music)&.merge(t: 0, music: true), *Array(@spec.dig(:audio, :sfx))].compact
  end

  def local_path(url)
    url.start_with?("/") ? Rails.root.join("public", url.delete_prefix("/")).to_s : url
  end

  def filter_graph
    [*shots.each_with_index.map { |shot, shot_index| shot_filter(shot, shot_index) },
     *transition_filters, "[#{last_video_label}]#{finishing_filters}[vout]", audio_graph].join(";")
  end

  def transition_filters
    shots.each_with_index.drop(1).map do |shot, shot_index|
      transition = shot[:transition] || {}
      ffmpeg_transition = FFMPEG_TRANSITIONS.fetch(transition[:type], DEFAULT_FFMPEG_TRANSITION)
      "[#{video_label(shot_index - 1)}][s#{shot_index}]xfade=transition=#{ffmpeg_transition}:" \
        "duration=#{overlap_seconds(transition)}:offset=#{shot[:start]}[x#{shot_index}]"
    end
  end

  def video_label(shot_index)
    shot_index.zero? ? "s0" : "x#{shot_index}"
  end

  def last_video_label
    video_label(shots.size - 1)
  end

  def overlap_seconds(transition)
    [transition.to_h[:duration].to_f, MINIMUM_OVERLAP].max
  end

  def shot_filter(shot, shot_index)
    following_shot = shots[shot_index + 1]
    length = shot[:duration] + (following_shot ? overlap_seconds(following_shot[:transition]) : 0) + SHOT_PADDING
    shot[:type] == "clip" ? clip_filter(shot, shot_index, length) : black_filter(shot_index, length)
  end

  def clip_filter(shot, shot_index, length)
    speed = shot[:speed].to_f
    zoom = interpolation(*shot[:zoom], length)
    (pan_start_x, pan_start_y), (pan_end_x, pan_end_y) = shot[:pan]
    pan_x = interpolation(pan_start_x, pan_end_x, length)
    pan_y = interpolation(pan_start_y, pan_end_y, length)
    filters = [
      "trim=start=#{shot[:in]}:duration=#{(length * speed + SOURCE_PADDING).round(3)}",
      "setpts=(PTS-STARTPTS)/#{speed}",
      "fps=#{FRAMES_PER_SECOND}",
      "scale=w='trunc(#{@width}*#{zoom}/2)*2':h='trunc(#{@height}*#{zoom}/2)*2':eval=frame",
      "crop=#{@width}:#{@height}:x='(in_w-#{@width})/2*(1+#{pan_x})':y='(in_h-#{@height})/2*(1+#{pan_y})'",
      ("hflip" if shot[:flip]),
      grade_filter,
      ("drawbox=color=black@#{shot[:dim]}:t=fill:enable='gte(t,#{DIM_DELAY})'" if shot[:dim].to_f.positive?),
      "trim=duration=#{length}", "setpts=PTS-STARTPTS", "fps=#{FRAMES_PER_SECOND}", "format=yuv420p", "setsar=1"
    ].compact
    "[#{@input_numbers[[:shot, shot_index]]}:v]#{filters.join(",")}[s#{shot_index}]"
  end

  def black_filter(shot_index, length)
    "color=c=black:s=#{@width}x#{@height}:r=#{FRAMES_PER_SECOND}:d=#{length},format=yuv420p,setsar=1[s#{shot_index}]"
  end

  def interpolation(start_value, end_value, length)
    "(#{start_value}+(#{end_value - start_value})*t/#{length})"
  end

  def grade_filter
    tint_channels = grade[:tint].to_s.delete("#").scan(/../).map { |hex| hex.hex / 255.0 }
    multipliers = tint_channels.map { |channel| (1 + (channel * TINT_STRENGTH - 1) * grade[:tint_amount].to_f).round(3) }
    brightness = ((grade[:brightness].to_f - 1) * BRIGHTNESS_STRENGTH).round(3)
    "eq=saturation=#{grade[:saturation]}:contrast=#{grade[:contrast]}:brightness=#{brightness}," \
      "colorchannelmixer=rr=#{multipliers[0]}:gg=#{multipliers[1]}:bb=#{multipliers[2]}"
  end

  def finishing_filters
    [
      vignette_filter,
      grain_filter,
      letterbox_filter,
      *@spec[:texts].each_with_index.map { |text_card, card_index| text_filter(text_card, card_index) },
      "fade=t=in:d=#{FADE_IN_SECONDS}",
      "fade=t=out:st=#{(duration - FADE_OUT_SECONDS).round(2)}:d=#{FADE_OUT_SECONDS}"
    ].compact.join(",")
  end

  def vignette_filter
    return unless grade[:vignette].to_f.positive?

    "vignette=angle=#{(VIGNETTE_BASE_ANGLE + grade[:vignette].to_f * VIGNETTE_ANGLE_RANGE).round(3)}"
  end

  def grain_filter
    "noise=alls=#{(grade[:grain].to_f * GRAIN_STRENGTH).round}:allf=t" if grade[:grain].to_f.positive?
  end

  def letterbox_filter
    return unless @spec[:letterbox]

    bar_height = (@height * LETTERBOX_SHARE).round
    "drawbox=x=0:y=0:w=iw:h=#{bar_height}:color=black:t=fill,drawbox=x=0:y=ih-#{bar_height}:w=iw:h=#{bar_height}:color=black:t=fill"
  end

  def text_filter(text_card, card_index)
    text_path = File.join(@work_directory, "text#{card_index}.txt")
    File.write(text_path, text_card[:text])
    starts_at = text_card[:start].to_f
    ends_at = starts_at + text_card[:duration].to_f
    visible_until = text_card[:title] ? duration : ends_at
    "drawtext=fontfile='#{font_path(text_card[:font])}':textfile='#{text_path}':fontsize=#{font_size(text_card)}:" \
      "fontcolor=#{text_card[:color]}:x=(w-text_w)/2:y=h*#{text_card[:y]}-text_h/2:shadowcolor=black@0.6:shadowx=0:shadowy=2:" \
      "alpha='#{fade_alpha_expression(starts_at, ends_at, text_card[:title])}':enable='between(t,#{starts_at},#{visible_until})'"
  end

  def font_path(family)
    path = FONT_DIRECTORY.join("#{family}.ttf")
    File.exist?(path) ? path : FONT_DIRECTORY.join("#{FALLBACK_FONT}.ttf")
  end

  def font_size(text_card)
    width_limited = (@width * TEXT_MAX_WIDTH_SHARE) / (text_card[:text].length * TEXT_CHARACTER_WIDTH)
    [text_card[:size].to_f * @height, width_limited].min.round
  end

  def fade_alpha_expression(starts_at, ends_at, stays_visible)
    fade_out = stays_visible ? "1" : "max(0,(#{ends_at}-t)/#{TEXT_FADE_OUT_SECONDS})"
    "if(lt(t,#{starts_at}),0,if(lt(t,#{starts_at + TEXT_FADE_IN_SECONDS}),(t-#{starts_at})/#{TEXT_FADE_IN_SECONDS}," \
      "if(lt(t,#{ends_at - TEXT_FADE_OUT_SECONDS}),1,#{fade_out})))"
  end

  def audio_graph
    sound_chains = sounds.each_with_index.map do |sound, sound_index|
      "[#{@input_numbers[[:sound, sound_index]]}:a]#{AUDIO_FORMAT},#{sound_chain(sound)}[a#{sound_index}]"
    end
    return "anullsrc=r=#{SAMPLE_RATE}:cl=stereo,atrim=duration=#{duration}[aout]" if sound_chains.empty?

    mix_inputs = sounds.each_index.map { |sound_index| "[a#{sound_index}]" }.join
    [*sound_chains, "#{mix_inputs}amix=inputs=#{sounds.size}:normalize=0:duration=longest,atrim=duration=#{duration}[aout]"].join(";")
  end

  def sound_chain(sound)
    return "adelay=#{delay_milliseconds(sound)}|#{delay_milliseconds(sound)},volume=#{sound[:gain]}" unless sound[:music]

    "atrim=start=#{sound[:offset]},asetpts=PTS-STARTPTS,volume=#{sound[:gain]}," \
      "afade=t=out:st=#{(duration - MUSIC_FADE_OUT_SECONDS).round(2)}:d=#{MUSIC_FADE_OUT_SECONDS}"
  end

  def delay_milliseconds(sound)
    (sound[:t].to_f * 1000).round
  end
end
