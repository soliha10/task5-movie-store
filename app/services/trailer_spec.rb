# Builds the deterministic description of one trailer: which footage, how it is cut,
# graded and zoomed, which text cards appear with which animation, and the sound mix.
# The browser player (trailer_controller.js) and the ffmpeg exporter (TrailerRenderer)
# only execute this description; every random decision is made here, on the server.
class TrailerSpec
  WIDTH = 640
  HEIGHT = 360

  # Trailer structures: each step is [kind, beats, card]. kind :clip shows footage,
  # :black is a text card on black, :title is the title reveal (over footage or black).
  STRUCTURES = {
    classic: [[:clip, 5, :when], [:black, 3, :hook], [:clip, 4, nil], [:title, 8, :ending]],
    cards:   [[:black, 3, :presents], [:clip, 4, nil], [:clip, 4, :hook], [:black, 3, :starring], [:title, 7, :ending]],
    montage: [[:clip, 3, :when], [:clip, 2, nil], [:clip, 2, nil], [:clip, 3, :hook], [:clip, 2, nil], [:title, 7, :ending]],
    slow:    [[:clip, 6, :hook], [:clip, 6, :starring], [:title, 8, :ending]],
    teaser:  [[:clip, 4, nil], [:clip, 4, :presents], [:black, 3, :hook], [:clip, 3, nil], [:title, 7, :when]]
  }.freeze

  def initialize(movie, region, rng)
    @movie = movie
    @region = region
    @rng = rng
    @genre = movie[:genre]
    @style = Catalog.genres.fetch(@genre)
  end

  def build
    @beat = 60.0 / rand_in(@style["bpm"])
    @grade = build_grade
    @font = pick(TrailerFonts.for_genre(@genre))
    @clips = MediaLibrary.clips_for(@genre).presence || MediaLibrary.clips
    @used_clips = []

    shots, texts = timeline
    duration = shots.sum { |s| s[:duration] }.round(2)
    title = texts.find { |t| t[:title] }
    {
      seed: @rng.rand(2**31),
      duration: duration,
      size: [WIDTH, HEIGHT],
      grade: @grade,
      letterbox: @rng.rand < 0.55,
      shots: shots,
      texts: texts,
      audio: build_audio(shots, title, duration),
      poster: build_poster(shots, title)
    }
  end

  private

  def timeline
    structure = pick(@movie[:kind] == :series ? STRUCTURES.values + [series_structure] : STRUCTURES.values)
    scale = rand_in([7.6, 9.4]) / (structure.sum { |step| step[1] } * @beat) # keep trailers 7.5-9.5 s
    t = 0.0
    shots = []
    texts = []

    structure.each_with_index do |(kind, beats, card), i|
      duration = (beats * @beat * scale).round(2)
      shot = kind == :black || (kind == :title && @rng.rand < 0.2) ? black_shot(duration) : clip_shot(duration, kind == :title)
      shot[:start] = t.round(2)
      shot[:transition] = i.zero? ? { type: "fade_in", duration: 0.5 } : transition
      shots << shot

      if kind == :title
        texts << title_text(t, duration)
        texts << card_text(card, t + duration * 0.4, duration * 0.6, small: true) if card
      elsif card
        lead = kind == :black ? 0.15 : rand_in([0.2, 0.6])
        texts << card_text(card, t + lead, duration - lead - 0.1)
      end
      t += duration
    end
    [shots, texts.compact]
  end

  def series_structure
    [[:clip, 4, :series], [:clip, 3, nil], [:black, 3, :hook], [:clip, 3, nil], [:title, 7, :ending]]
  end

  def clip_shot(duration, title)
    clip = next_clip
    return black_shot(duration) unless clip

    speed = (@rng.rand < 0.45 ? rand_in([0.55, 0.85]) : rand_in([0.9, 1.25])).round(2)
    usable = clip["duration"].to_f - 0.1
    speed = [speed, usable / duration].min.round(2) # never run past the end of the footage
    source = duration * speed
    zoom = [rand_in([1.0, 1.12]), rand_in([1.12, 1.35])]
    zoom.reverse! if @rng.rand < 0.4
    {
      type: "clip",
      clip: clip["id"],
      url: MediaLibrary.url(clip["file"]),
      thumb: MediaLibrary.url(clip["thumb"]),
      duration: duration,
      in: rand_in([0.0, [usable - source, 0.0].max]).round(2),
      speed: speed,
      zoom: zoom.map { _1.round(3) },
      pan: Array.new(2) { [rand_in([-1.0, 1.0]).round(2), rand_in([-1.0, 1.0]).round(2)] },
      flip: @rng.rand < 0.25,
      dim: title ? rand_in([0.35, 0.55]).round(2) : 0.0
    }
  end

  def black_shot(duration)
    { type: "black", duration: duration }
  end

  def next_clip
    pool = @clips - @used_clips
    pool = @clips if pool.empty?
    pick(pool).tap { |clip| @used_clips << clip if clip }
  end

  def transition
    type = pick(@style["transitions"])
    duration = { "cut" => 0.0, "flash" => 0.25, "dip_black" => 0.5, "dip_white" => 0.4, "dissolve" => 0.6,
                 "zoom_blur" => 0.35, "whip" => 0.3, "glitch" => 0.3, "light_leak" => 0.7, "flicker" => 0.4 }.fetch(type, 0.3)
    { type: type, duration: duration }
  end

  def title_text(start, duration)
    text = @movie[:title]
    script = script?(@font)
    {
      title: true,
      text: script || @rng.rand < 0.2 ? text : text.upcase,
      start: (start + rand_in([0.15, 0.45])).round(2),
      duration: (duration - 0.5).round(2),
      style: pick(@style["text_styles"]),
      font: @font["family"],
      weight: @font["weights"].max,
      color: pick(@style["title_colors"]),
      size: rand_in([0.1, 0.13]).round(3),
      tracking: rand_in([0.02, 0.12]).round(3),
      y: 0.5
    }
  end

  def card_text(kind, start, duration, small: false)
    text = case kind
           when :hook then Faker::MovieStore.trailer_hook(genre: @genre)
           when :starring then Faker::MovieStore.trailer_card(:starring, context: { actor: @movie[:cast].first.upcase })
           else Faker::MovieStore.trailer_card(kind, context: card_context)
           end
    font = small || @rng.rand < 0.6 ? @font : pick(TrailerFonts.for_genre(@genre))
    font = pick(TrailerFonts.for_genre(@genre).reject { script?(_1) }.presence || TrailerFonts.all.reject { script?(_1) }) if script?(font)
    {
      title: false,
      text: text.upcase,
      start: start.round(2),
      duration: duration.round(2),
      style: pick(@style["text_styles"]),
      font: font["family"],
      weight: font["weights"].min,
      color: small ? "#e8e8e8" : "#ffffff",
      size: small ? 0.042 : rand_in([0.055, 0.075]).round(3),
      tracking: rand_in([0.08, 0.25]).round(3),
      y: small ? 0.7 : (@rng.rand < 0.75 ? 0.5 : 0.78)
    }
  end

  def card_context
    {
      other_title: Faker::MovieStore.title(genre: @genre).upcase,
      year: @movie[:year].to_s,
      studio: Faker::MovieStore.trailer_card(:studio)
    }
  end

  def build_grade
    name = pick(@style["grades"])
    preset = Catalog.grades.fetch(name)
    grade = { name: name }
    %w[saturation contrast brightness tint_amount vignette grain bloom rgb_split].each do |key|
      grade[key.to_sym] = preset[key] ? rand_in(preset[key]).round(3) : 0.0
    end
    grade[:tint] = pick(preset["tint"])
    grade
  end

  def build_audio(shots, title, duration)
    music = pick(MediaLibrary.audio_for("music", @genre).presence || MediaLibrary.audio_for("music"))
    sfx = []
    title_at = title ? title[:start] : duration - 3
    hit = sfx_of(@style.dig("sfx", "hit"))
    sfx << { url: hit, t: title_at.round(2), gain: rand_in([0.7, 0.95]).round(2) } if hit
    if (atmosphere = sfx_of(@style.dig("sfx", "atmosphere")))
      sfx << { url: atmosphere, t: [title_at - rand_in([2.5, 3.5]), 0].max.round(2), gain: rand_in([0.45, 0.7]).round(2) }
    end
    cut_kinds = @style.dig("sfx", "cut")
    shots.drop(1).each do |shot|
      next unless cut_kinds.any? && shot[:start] < title_at - 0.3 && @rng.rand < 0.5

      sfx << { url: sfx_of(cut_kinds), t: [shot[:start] - 0.2, 0].max.round(2), gain: rand_in([0.35, 0.6]).round(2) }
    end
    {
      music: music && { url: MediaLibrary.url(music["file"]), offset: rand_in([0.0, 1.0]).round(2), gain: rand_in([0.75, 0.95]).round(2) },
      sfx: sfx.select { _1[:url] }
    }
  end

  def sfx_of(kinds)
    kind = pick(Array(kinds))
    return nil unless kind

    item = pick(MediaLibrary.audio_for("sfx", kind))
    item && MediaLibrary.url(item["file"])
  end

  def build_poster(shots, title)
    shot = shots.reverse.find { |s| s[:type] == "clip" }
    {
      image: shot&.dig(:thumb),
      filter: "filter: saturate(#{@grade[:saturation]}) contrast(#{@grade[:contrast]}) brightness(#{@grade[:brightness]});",
      style: "--tint: #{@grade[:tint]}; --tint-amount: #{@grade[:tint_amount]};",
      title_style: title && "font-family: '#{title[:font]}', sans-serif; font-weight: #{title[:weight]}; color: #{title[:color]}; letter-spacing: #{title[:tracking]}em;" \
                            "#{" text-transform: none;" if title[:text] != title[:text].upcase}"
    }
  end

  # Handwritten fonts look wrong in capitals, so they are only used for mixed-case titles.
  def script?(font)
    font["family"].match?(/Script|Lobster/)
  end

  def pick(list)
    list = Array(list)
    list.empty? ? nil : list[@rng.rand(list.size)]
  end

  def rand_in((min, max))
    min + @rng.rand * (max - min)
  end
end
