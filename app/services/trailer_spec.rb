class TrailerSpec
  WIDTH = 640
  HEIGHT = 360
  SEED_LIMIT = 2**31
  SECONDS_PER_MINUTE = 60.0
  TARGET_DURATION = [7.6, 9.4].freeze
  LETTERBOX_CHANCE = 0.55
  BLACK_TITLE_CHANCE = 0.2
  OPENING_TRANSITION = { type: "fade_in", duration: 0.5 }.freeze
  TRANSITION_DURATIONS = {
    "cut" => 0.0, "flash" => 0.25, "dip_black" => 0.5, "dip_white" => 0.4, "dissolve" => 0.6,
    "zoom_blur" => 0.35, "whip" => 0.3, "glitch" => 0.3, "light_leak" => 0.7, "flicker" => 0.4
  }.freeze
  DEFAULT_TRANSITION_DURATION = 0.3

  SLOW_MOTION_CHANCE = 0.45
  SLOW_MOTION_SPEED = [0.55, 0.85].freeze
  NORMAL_SPEED = [0.9, 1.25].freeze
  CLIP_END_MARGIN = 0.1
  ZOOM_NEAR = [1.0, 1.12].freeze
  ZOOM_FAR = [1.12, 1.35].freeze
  ZOOM_OUT_CHANCE = 0.4
  PAN_RANGE = [-1.0, 1.0].freeze
  FLIP_CHANCE = 0.25
  TITLE_DIM = [0.35, 0.55].freeze

  TITLE_DELAY = [0.15, 0.45].freeze
  TITLE_TAIL = 0.5
  MIXED_CASE_TITLE_CHANCE = 0.2
  TITLE_SIZE = [0.1, 0.13].freeze
  TITLE_TRACKING = [0.02, 0.12].freeze
  ENDING_CARD_START = 0.4
  ENDING_CARD_LENGTH = 0.6
  BLACK_CARD_LEAD = 0.15
  FOOTAGE_CARD_LEAD = [0.2, 0.6].freeze
  CARD_TAIL = 0.1
  GENRE_FONT_CHANCE = 0.6
  CARD_SIZE = [0.055, 0.075].freeze
  SMALL_CARD_SIZE = 0.042
  CARD_TRACKING = [0.08, 0.25].freeze
  CENTERED_CARD_CHANCE = 0.75
  CENTER_Y = 0.5
  LOWER_CARD_Y = 0.78
  SMALL_CARD_Y = 0.7
  CARD_COLOR = "#ffffff"
  SMALL_CARD_COLOR = "#e8e8e8"
  SCRIPT_FONT = /Script|Lobster/

  GRADE_SETTINGS = %w[saturation contrast brightness tint_amount vignette grain bloom rgb_split].freeze

  MUSIC_OFFSET = [0.0, 1.0].freeze
  MUSIC_GAIN = [0.75, 0.95].freeze
  FALLBACK_TITLE_LEAD = 3
  HIT_GAIN = [0.7, 0.95].freeze
  ATMOSPHERE_LEAD = [2.5, 3.5].freeze
  ATMOSPHERE_GAIN = [0.45, 0.7].freeze
  CUT_SOUND_CHANCE = 0.5
  CUT_SOUND_LEAD = 0.2
  CUT_SOUND_TITLE_GAP = 0.3
  CUT_SOUND_GAIN = [0.35, 0.6].freeze

  Step = Data.define(:kind, :beats, :card)

  def self.structure(*steps)
    steps.map { |kind, beats, card| Step.new(kind:, beats:, card:) }.freeze
  end

  STRUCTURES = [
    structure([:clip, 5, :when], [:black, 3, :hook], [:clip, 4, nil], [:title, 8, :ending]),
    structure([:black, 3, :presents], [:clip, 4, nil], [:clip, 4, :hook], [:black, 3, :starring], [:title, 7, :ending]),
    structure([:clip, 3, :when], [:clip, 2, nil], [:clip, 2, nil], [:clip, 3, :hook], [:clip, 2, nil], [:title, 7, :ending]),
    structure([:clip, 6, :hook], [:clip, 6, :starring], [:title, 8, :ending]),
    structure([:clip, 4, nil], [:clip, 4, :presents], [:black, 3, :hook], [:clip, 3, nil], [:title, 7, :when])
  ].freeze
  SERIES_STRUCTURE = structure([:clip, 4, :series], [:clip, 3, nil], [:black, 3, :hook], [:clip, 3, nil], [:title, 7, :ending])

  def initialize(movie, region, random)
    @movie = movie
    @region = region
    @random = random
    @genre = movie[:genre]
    @style = Catalog.genre_style(@genre)
  end

  def build
    @beat_seconds = SECONDS_PER_MINUTE / random_between(@style["bpm"])
    @grade = build_grade
    @font = random_item(TrailerFonts.for_genre(@genre))
    @clips = MediaLibrary.clips_for(@genre).presence || MediaLibrary.clips
    @used_clips = []

    shots, text_cards = build_timeline
    duration = shots.sum { |shot| shot[:duration] }.round(2)
    title_card = text_cards.find { |card| card[:title] }
    {
      seed: @random.rand(SEED_LIMIT),
      duration: duration,
      size: [WIDTH, HEIGHT],
      grade: @grade,
      letterbox: @random.rand < LETTERBOX_CHANCE,
      shots: shots,
      texts: text_cards,
      audio: build_audio(shots, title_card, duration),
      poster: build_poster(shots, title_card)
    }
  end

  private

  def build_timeline
    steps = random_item(@movie[:kind] == :series ? STRUCTURES + [SERIES_STRUCTURE] : STRUCTURES)
    time_scale = random_between(TARGET_DURATION) / (steps.sum(&:beats) * @beat_seconds)
    elapsed_seconds = 0.0
    shots = []
    text_cards = []

    steps.each_with_index do |step, step_index|
      duration = (step.beats * @beat_seconds * time_scale).round(2)
      shot = build_shot(step, duration)
      shot[:start] = elapsed_seconds.round(2)
      shot[:transition] = step_index.zero? ? OPENING_TRANSITION.dup : build_transition
      shots << shot
      text_cards.concat(step_text_cards(step, elapsed_seconds, duration))
      elapsed_seconds += duration
    end
    [shots, text_cards.compact]
  end

  def build_shot(step, duration)
    title_step = step.kind == :title
    black = step.kind == :black || (title_step && @random.rand < BLACK_TITLE_CHANCE)
    black ? black_shot(duration) : clip_shot(duration, title_step)
  end

  def step_text_cards(step, starts_at, duration)
    if step.kind == :title
      title = title_text(starts_at, duration)
      ending = step.card && card_text(step.card, starts_at + duration * ENDING_CARD_START, duration * ENDING_CARD_LENGTH, small: true)
      [title, ending].compact
    elsif step.card
      lead = step.kind == :black ? BLACK_CARD_LEAD : random_between(FOOTAGE_CARD_LEAD)
      [card_text(step.card, starts_at + lead, duration - lead - CARD_TAIL)]
    else
      []
    end
  end

  def clip_shot(duration, title_step)
    clip = next_clip
    return black_shot(duration) unless clip

    usable_seconds = clip["duration"].to_f - CLIP_END_MARGIN
    speed = [playback_speed, usable_seconds / duration].min.round(2)
    source_seconds = duration * speed
    zoom = [random_between(ZOOM_NEAR), random_between(ZOOM_FAR)]
    zoom.reverse! if @random.rand < ZOOM_OUT_CHANCE
    {
      type: "clip",
      clip: clip["id"],
      url: MediaLibrary.url(clip["file"]),
      thumb: MediaLibrary.url(clip["thumb"]),
      duration: duration,
      in: random_between([0.0, [usable_seconds - source_seconds, 0.0].max]).round(2),
      speed: speed,
      zoom: zoom.map { |level| level.round(3) },
      pan: Array.new(2) { [random_between(PAN_RANGE).round(2), random_between(PAN_RANGE).round(2)] },
      flip: @random.rand < FLIP_CHANCE,
      dim: title_step ? random_between(TITLE_DIM).round(2) : 0.0
    }
  end

  def playback_speed
    (@random.rand < SLOW_MOTION_CHANCE ? random_between(SLOW_MOTION_SPEED) : random_between(NORMAL_SPEED)).round(2)
  end

  def black_shot(duration)
    { type: "black", duration: duration }
  end

  def next_clip
    unused_clips = @clips - @used_clips
    random_item(unused_clips.empty? ? @clips : unused_clips).tap { |clip| @used_clips << clip if clip }
  end

  def build_transition
    type = random_item(@style["transitions"])
    { type: type, duration: TRANSITION_DURATIONS.fetch(type, DEFAULT_TRANSITION_DURATION) }
  end

  def title_text(starts_at, duration)
    title = @movie[:title]
    {
      title: true,
      text: script_font?(@font) || @random.rand < MIXED_CASE_TITLE_CHANCE ? title : title.upcase,
      start: (starts_at + random_between(TITLE_DELAY)).round(2),
      duration: (duration - TITLE_TAIL).round(2),
      style: random_item(@style["text_styles"]),
      font: @font["family"],
      weight: @font["weights"].max,
      color: random_item(@style["title_colors"]),
      size: random_between(TITLE_SIZE).round(3),
      tracking: random_between(TITLE_TRACKING).round(3),
      y: CENTER_Y
    }
  end

  def card_text(kind, starts_at, duration, small: false)
    text = card_wording(kind)
    font = card_font(small)
    {
      title: false,
      text: text.upcase,
      start: starts_at.round(2),
      duration: duration.round(2),
      style: random_item(@style["text_styles"]),
      font: font["family"],
      weight: font["weights"].min,
      color: small ? SMALL_CARD_COLOR : CARD_COLOR,
      size: small ? SMALL_CARD_SIZE : random_between(CARD_SIZE).round(3),
      tracking: random_between(CARD_TRACKING).round(3),
      y: small ? SMALL_CARD_Y : card_y_position
    }
  end

  def card_wording(kind)
    case kind
    when :hook then Faker::MovieStore.trailer_hook(genre: @genre)
    when :starring then Faker::MovieStore.trailer_card(:starring, context: { actor: @movie[:cast].first.upcase })
    else Faker::MovieStore.trailer_card(kind, context: card_context)
    end
  end

  def card_font(small)
    font = small || @random.rand < GENRE_FONT_CHANCE ? @font : random_item(TrailerFonts.for_genre(@genre))
    script_font?(font) ? random_item(block_fonts) : font
  end

  def block_fonts
    TrailerFonts.for_genre(@genre).reject { |font| script_font?(font) }.presence ||
      TrailerFonts.all.reject { |font| script_font?(font) }
  end

  def card_y_position
    @random.rand < CENTERED_CARD_CHANCE ? CENTER_Y : LOWER_CARD_Y
  end

  def card_context
    {
      other_title: Faker::MovieStore.title(genre: @genre).upcase,
      year: @movie[:year].to_s,
      studio: Faker::MovieStore.trailer_card(:studio)
    }
  end

  def build_grade
    name = random_item(@style["grades"])
    preset = Catalog.grades.fetch(name)
    grade = { name: name }
    GRADE_SETTINGS.each do |setting|
      grade[setting.to_sym] = preset[setting] ? random_between(preset[setting]).round(3) : 0.0
    end
    grade[:tint] = random_item(preset["tint"])
    grade
  end

  def build_audio(shots, title_card, duration)
    music = random_item(MediaLibrary.audio_for("music", @genre).presence || MediaLibrary.audio_for("music"))
    title_time = title_card ? title_card[:start] : duration - FALLBACK_TITLE_LEAD
    sound_effects = [title_hit(title_time), atmosphere_sound(title_time), *cut_sounds(shots, title_time)]
    {
      music: music && music_track(music),
      sfx: sound_effects.compact.select { |effect| effect[:url] }
    }
  end

  def music_track(music)
    { url: MediaLibrary.url(music["file"]), offset: random_between(MUSIC_OFFSET).round(2), gain: random_between(MUSIC_GAIN).round(2) }
  end

  def title_hit(title_time)
    url = sound_effect_url(@style.dig("sfx", "hit"))
    url && { url: url, t: title_time.round(2), gain: random_between(HIT_GAIN).round(2) }
  end

  def atmosphere_sound(title_time)
    url = sound_effect_url(@style.dig("sfx", "atmosphere"))
    url && { url: url, t: [title_time - random_between(ATMOSPHERE_LEAD), 0].max.round(2), gain: random_between(ATMOSPHERE_GAIN).round(2) }
  end

  def cut_sounds(shots, title_time)
    cut_kinds = @style.dig("sfx", "cut")
    shots.drop(1).filter_map do |shot|
      next unless cut_kinds.any? && shot[:start] < title_time - CUT_SOUND_TITLE_GAP && @random.rand < CUT_SOUND_CHANCE

      { url: sound_effect_url(cut_kinds), t: [shot[:start] - CUT_SOUND_LEAD, 0].max.round(2), gain: random_between(CUT_SOUND_GAIN).round(2) }
    end
  end

  def sound_effect_url(kinds)
    kind = random_item(Array(kinds))
    return nil unless kind

    effect = random_item(MediaLibrary.audio_for("sfx", kind))
    effect && MediaLibrary.url(effect["file"])
  end

  def build_poster(shots, title_card)
    poster_shot = shots.reverse.find { |shot| shot[:type] == "clip" }
    {
      image: poster_shot&.dig(:thumb),
      filter: "filter: saturate(#{@grade[:saturation]}) contrast(#{@grade[:contrast]}) brightness(#{@grade[:brightness]});",
      style: "--tint: #{@grade[:tint]}; --tint-amount: #{@grade[:tint_amount]};",
      title_style: title_card && poster_title_style(title_card)
    }
  end

  def poster_title_style(title_card)
    style = "font-family: '#{title_card[:font]}', sans-serif; font-weight: #{title_card[:weight]}; " \
            "color: #{title_card[:color]}; letter-spacing: #{title_card[:tracking]}em;"
    title_card[:text] == title_card[:text].upcase ? style : "#{style} text-transform: none;"
  end

  def script_font?(font)
    font["family"].match?(SCRIPT_FONT)
  end

  def random_item(list)
    list = Array(list)
    list.empty? ? nil : list[@random.rand(list.size)]
  end

  def random_between((minimum, maximum))
    minimum + @random.rand * (maximum - minimum)
  end
end
