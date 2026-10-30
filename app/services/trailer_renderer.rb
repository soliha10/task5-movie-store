require "open3"
require "digest"

# Renders a TrailerSpec into an MP4 with ffmpeg (used by the ZIP export).
# The browser player has richer typography; this renderer keeps the same footage,
# timing, zoom/pan, grade, transitions, text cards and sound mix.
class TrailerRenderer
  CACHE = Rails.root.join("tmp/trailers")
  FONTS = Rails.root.join("vendor/fonts")
  FPS = 24
  XFADE = { "dissolve" => "fade", "fade_in" => "fade", "dip_black" => "fadeblack", "dip_white" => "fadewhite",
            "flash" => "fadewhite", "zoom_blur" => "zoomin", "whip" => "slideleft", "glitch" => "pixelize",
            "light_leak" => "fade", "flicker" => "fadeblack", "cut" => "fade" }.freeze

  def initialize(spec)
    @spec = spec.deep_symbolize_keys
    @w, @h = @spec[:size]
  end

  # Path of the rendered file (rendered once, then served from the cache).
  def render
    FileUtils.mkdir_p(CACHE)
    out = CACHE.join("#{Digest::SHA256.hexdigest(@spec.to_json)[0, 24]}.mp4")
    return out if File.size?(out)

    Dir.mktmpdir do |dir|
      @tmp = dir
      tmp_out = File.join(dir, "out.mp4")
      _, err, status = Open3.capture3("ffmpeg", "-y", "-v", "error", *inputs, "-filter_complex", graph,
                                      "-map", "[vout]", "-map", "[aout]", "-c:v", "libx264", "-preset", "veryfast",
                                      "-crf", "23", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
                                      "-movflags", "+faststart", "-t", @spec[:duration].to_s, tmp_out)
      raise "ffmpeg failed: #{err.lines.last(5).join}" unless status.success?

      FileUtils.mv(tmp_out, out)
    end
    out
  end

  private

  def shots = @spec[:shots]
  def duration = @spec[:duration]

  def inputs
    @input_index = {}
    args = []
    shots.each_with_index do |shot, i|
      next unless shot[:type] == "clip"

      @input_index[[:shot, i]] = args.size / 2
      args += ["-i", local(shot[:url])]
    end
    sounds.each_with_index do |sound, i|
      @input_index[[:sound, i]] = args.size / 2
      args += ["-i", local(sound[:url])]
    end
    args
  end

  def sounds
    @sounds ||= [(@spec.dig(:audio, :music)&.merge(t: 0, music: true)), *Array(@spec.dig(:audio, :sfx))].compact
  end

  # "/media/clips/1.mp4" -> public/media/clips/1.mp4; remote URLs are read by ffmpeg directly.
  def local(url)
    url.start_with?("/") ? Rails.root.join("public", url.delete_prefix("/")).to_s : url
  end

  def graph
    parts = shots.each_with_index.map { |shot, i| shot_filter(shot, i) }
    label = "s0"
    shots.each_with_index.drop(1).each do |shot, i|
      trans = shot[:transition] || {}
      d = [trans[:duration].to_f, 0.04].max
      parts << "[#{label}][s#{i}]xfade=transition=#{XFADE.fetch(trans[:type], "fade")}:duration=#{d}:offset=#{shot[:start]}[x#{i}]"
      label = "x#{i}"
    end
    parts << "[#{label}]#{finish_filters}[vout]"
    parts << audio_graph
    parts.join(";")
  end

  def shot_filter(shot, i)
    following = shots[i + 1]
    length = shot[:duration] + (following ? [following.dig(:transition, :duration).to_f, 0.04].max : 0) + 0.05
    if shot[:type] == "clip"
      speed = shot[:speed].to_f
      z0, z1 = shot[:zoom]
      (p0x, p0y), (p1x, p1y) = shot[:pan]
      zoom = "(#{z0}+(#{z1 - z0})*t/#{length})"
      pan_x = "(#{p0x}+(#{p1x - p0x})*t/#{length})"
      pan_y = "(#{p0y}+(#{p1y - p0y})*t/#{length})"
      chain = [
        "trim=start=#{shot[:in]}:duration=#{(length * speed + 0.2).round(3)}",
        "setpts=(PTS-STARTPTS)/#{speed}",
        "fps=#{FPS}",
        "scale=w='trunc(#{@w}*#{zoom}/2)*2':h='trunc(#{@h}*#{zoom}/2)*2':eval=frame",
        "crop=#{@w}:#{@h}:x='(in_w-#{@w})/2*(1+#{pan_x})':y='(in_h-#{@h})/2*(1+#{pan_y})'",
        ("hflip" if shot[:flip]),
        grade_filter,
        ("drawbox=color=black@#{shot[:dim]}:t=fill:enable='gte(t,0.3)'" if shot[:dim].to_f.positive?),
        "trim=duration=#{length}", "setpts=PTS-STARTPTS", "format=yuv420p", "setsar=1"
      ].compact
      "[#{@input_index[[:shot, i]]}:v]#{chain.join(",")}[s#{i}]"
    else
      "color=c=black:s=#{@w}x#{@h}:r=#{FPS}:d=#{length},format=yuv420p,setsar=1[s#{i}]"
    end
  end

  def grade_filter
    g = @spec[:grade]
    tint = g[:tint].to_s.delete("#").scan(/../).map { |c| c.hex / 255.0 }
    mix = tint.map { |c| (1 + (c * 1.7 - 1) * g[:tint_amount].to_f).round(3) }
    "eq=saturation=#{g[:saturation]}:contrast=#{g[:contrast]}:brightness=#{((g[:brightness].to_f - 1) * 0.4).round(3)}," \
      "colorchannelmixer=rr=#{mix[0]}:gg=#{mix[1]}:bb=#{mix[2]}"
  end

  def finish_filters
    g = @spec[:grade]
    filters = []
    filters << "vignette=angle=#{(0.3 + g[:vignette].to_f * 0.5).round(3)}" if g[:vignette].to_f.positive?
    filters << "noise=alls=#{(g[:grain].to_f * 60).round}:allf=t" if g[:grain].to_f.positive?
    if @spec[:letterbox]
      bar = (@h * 0.11).round
      filters << "drawbox=x=0:y=0:w=iw:h=#{bar}:color=black:t=fill,drawbox=x=0:y=ih-#{bar}:w=iw:h=#{bar}:color=black:t=fill"
    end
    filters += @spec[:texts].each_with_index.map { |card, i| text_filter(card, i) }
    filters << "fade=t=in:d=0.4" << "fade=t=out:st=#{(duration - 0.5).round(2)}:d=0.5"
    filters.join(",")
  end

  def text_filter(card, i)
    file = File.join(@tmp, "text#{i}.txt")
    File.write(file, card[:text])
    font = FONTS.join("#{card[:font]}.ttf")
    font = FONTS.join("Oswald.ttf") unless File.exist?(font)
    size = [card[:size].to_f * @h, (@w * 0.86) / (card[:text].length * 0.58)].min.round
    s = card[:start].to_f
    e = s + card[:duration].to_f
    fade_out = card[:title] ? "1" : "max(0,(#{e}-t)/0.3)"
    alpha = "if(lt(t,#{s}),0,if(lt(t,#{s + 0.5}),(t-#{s})/0.5,if(lt(t,#{e - 0.3}),1,#{fade_out})))"
    "drawtext=fontfile='#{font}':textfile='#{file}':fontsize=#{size}:fontcolor=#{card[:color]}:" \
      "x=(w-text_w)/2:y=h*#{card[:y]}-text_h/2:shadowcolor=black@0.6:shadowx=0:shadowy=2:" \
      "alpha='#{alpha}':enable='between(t,#{s},#{card[:title] ? duration : e})'"
  end

  def audio_graph
    labels = sounds.each_with_index.map do |sound, i|
      input = @input_index[[:sound, i]]
      chain = if sound[:music]
                "atrim=start=#{sound[:offset]},asetpts=PTS-STARTPTS,volume=#{sound[:gain]}," \
                  "afade=t=out:st=#{(duration - 1.2).round(2)}:d=1.2"
              else
                ms = (sound[:t].to_f * 1000).round
                "adelay=#{ms}|#{ms},volume=#{sound[:gain]}"
              end
      "[#{input}:a]aformat=sample_rates=44100:channel_layouts=stereo,#{chain}[a#{i}]"
    end
    return "anullsrc=r=44100:cl=stereo,atrim=duration=#{duration}[aout]" if labels.empty?

    mix = sounds.each_index.map { |i| "[a#{i}]" }.join
    (labels + ["#{mix}amix=inputs=#{sounds.size}:normalize=0:duration=longest,atrim=duration=#{duration}[aout]"]).join(";")
  end
end
