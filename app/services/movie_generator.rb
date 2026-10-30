class MovieGenerator
  MOVIES_PER_PAGE = 20
  AVERAGE_RANGE = (0.0..10.0)
  SERIES_CHANCE = 0.15
  RECENT_YEARS = (2008..2026)
  CLASSIC_YEARS = (1972..2007)
  RECENT_MOVIE_CHANCE = 0.75
  CAST_SIZE = (2..5)
  STAGE_NAME_CHANCE = 0.06
  MOVIE_RUNTIME_MINUTES = (82..172)
  EPISODE_RUNTIME_MINUTES = (38..62)
  SEASON_COUNT = (1..7)
  EPISODES_PER_SEASON = (6..13)
  SCORE_BASE = (25..95)
  SCORE_BONUS = (0..5)
  SCORE_SCALE = 10.0
  BADGE_CHANCES = { top10: 0.12, new: 0.6, award: 0.08, exclusive: 0.07, uhd: 0.2 }.freeze
  NEW_RELEASE_YEAR = 2025
  MAX_BADGES = 2
  REVIEW_MOOD_SPREAD = (-2.5..2.5)
  POSITIVE_REVIEW_THRESHOLD = 6.5
  MIXED_REVIEW_THRESHOLD = 4.5

  attr_reader :region, :seed, :likes, :reviews

  def initialize(region:, seed:, likes: 0, reviews: 0)
    @region = region
    @seed = seed
    @likes = likes.to_f.clamp(AVERAGE_RANGE)
    @reviews = reviews.to_f.clamp(AVERAGE_RANGE)
  end

  def page(page_number)
    page_number = [page_number.to_i, 1].max
    page_seed = Seeding.page_seed(seed, page_number)
    (1..MOVIES_PER_PAGE).map do |position|
      build_movie(page_seed, (page_number - 1) * MOVIES_PER_PAGE + position, position)
    end
  end

  def movie(index)
    page_number = (index - 1) / MOVIES_PER_PAGE + 1
    build_movie(Seeding.page_seed(seed, page_number), index, (index - 1) % MOVIES_PER_PAGE + 1)
  end

  private

  def build_movie(page_seed, index, position)
    seed_for = ->(stream_name) { Seeding.record_seed(page_seed, position, region.seed_salt, stream_name) }
    details = with_seeded_faker(seed_for.call("core")) { |random| movie_details(random) }
    trailer = with_seeded_faker(seed_for.call("trailer")) { |random| TrailerSpec.new(details, region, random).build }
    Movie.new(index: index, **details,
              likes: with_random(seed_for.call("likes")) { |random| average_count(likes, random) },
              reviews: build_reviews(details, seed_for),
              trailer: trailer)
  end

  def movie_details(random)
    genre = Catalog.weighted_genre(random)
    series = random.rand < SERIES_CHANCE
    year = release_year(series, random)
    cast = build_cast(random)
    hero = Faker::MovieStore.character
    rival = Faker::MovieStore.character
    {
      kind: series ? :series : :movie,
      genre: genre,
      genre_name: Faker::MovieStore.genre_name(genre),
      title: Faker::MovieStore.title(genre: genre),
      year: year,
      cast: cast,
      director: Faker::MovieStore.person,
      **running_time(series, random),
      age_rating: age_rating(genre, random),
      badges: badges(year, random),
      plot: Faker::MovieStore.plot(genre: genre, context: { hero: hero, rival: rival, city: Faker::Address.city }),
      score: (random.rand(SCORE_BASE) + random.rand(SCORE_BONUS)) / SCORE_SCALE
    }
  end

  def release_year(series, random)
    return random.rand(RECENT_YEARS) if series

    random.rand < RECENT_MOVIE_CHANCE ? random.rand(RECENT_YEARS) : random.rand(CLASSIC_YEARS)
  end

  def build_cast(random)
    Array.new(random.rand(CAST_SIZE)) do
      random.rand < STAGE_NAME_CHANCE ? Faker::MovieStore.stage_name : Faker::MovieStore.person
    end.uniq
  end

  def running_time(series, random)
    return { runtime: random.rand(MOVIE_RUNTIME_MINUTES), seasons: nil, episodes: nil } unless series

    { runtime: random.rand(EPISODE_RUNTIME_MINUTES), seasons: random.rand(SEASON_COUNT), episodes: random.rand(EPISODES_PER_SEASON) }
  end

  def age_rating(genre, random)
    lowest, highest = Catalog.genre_style(genre)["ratings"]
    ratings = region.age_ratings
    ratings[random.rand(lowest..[highest, ratings.size - 1].min)]
  end

  def badges(year, random)
    BADGE_CHANCES.select { |badge, chance| badge_allowed?(badge, year) && random.rand < chance }.keys.first(MAX_BADGES)
  end

  def badge_allowed?(badge, year)
    badge != :new || year >= NEW_RELEASE_YEAR
  end

  def average_count(average, random)
    whole_part = average.floor
    whole_part + (random.rand < (average - whole_part) ? 1 : 0)
  end

  def build_reviews(details, seed_for)
    review_count = with_random(seed_for.call("reviews")) { |random| average_count(reviews, random) }
    Array.new(review_count) do |review_number|
      with_seeded_faker(seed_for.call("review:#{review_number}")) { |random| build_review(details, random) }
    end
  end

  def build_review(details, random)
    sentiment = review_sentiment(details[:score] + random.rand(REVIEW_MOOD_SPREAD))
    actors = details[:cast].shuffle(random: random)
    context = { title: details[:title], actor: actors.first, actor2: actors[1] || actors.first }
    Review.new(author: Faker::MovieStore.person, publication: Faker::MovieStore.publication,
               text: Faker::MovieStore.review(sentiment: sentiment, context: context), sentiment: sentiment)
  end

  def review_sentiment(mood)
    return "positive" if mood >= POSITIVE_REVIEW_THRESHOLD
    return "mixed" if mood >= MIXED_REVIEW_THRESHOLD

    "negative"
  end

  def with_random(seed)
    yield Random.new(seed)
  end

  def with_seeded_faker(seed)
    random = Random.new(seed)
    previous_random = Faker::Config.random
    previous_locale = Faker::Config.own_locale
    Faker::Config.random = random
    Faker::Config.locale = region.faker_locale
    yield random
  ensure
    Faker::Config.random = previous_random
    Faker::Config.locale = previous_locale
  end
end
