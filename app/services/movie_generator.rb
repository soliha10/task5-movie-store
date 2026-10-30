# Generates one page (batch) of movies purely from the parameters.
class MovieGenerator
  PER_PAGE = 20
  SERIES_SHARE = 0.15

  attr_reader :region, :seed, :likes, :reviews

  def initialize(region:, seed:, likes: 0, reviews: 0)
    @region = region
    @seed = seed
    @likes = likes.to_f.clamp(0.0, 10.0)
    @reviews = reviews.to_f.clamp(0.0, 10.0)
  end

  def page(number)
    number = [number.to_i, 1].max
    page_seed = Seeding.page_seed(seed, number)
    (1..PER_PAGE).map { |pos| build(page_seed, (number - 1) * PER_PAGE + pos, pos) }
  end

  def movie(index)
    number = (index - 1) / PER_PAGE + 1
    build(Seeding.page_seed(seed, number), index, (index - 1) % PER_PAGE + 1)
  end

  private

  def build(page_seed, index, pos)
    stream = ->(name) { Seeding.record_seed(page_seed, pos, region.salt, name) }
    core = with_faker(stream.call("core")) { |rng| core_fields(rng) }
    trailer = with_faker(stream.call("trailer")) { |rng| TrailerSpec.new(core, region, rng).build }
    Movie.new(index: index, **core,
              likes: with_rng(stream.call("likes")) { |rng| average_count(likes, rng) },
              reviews: build_reviews(core, stream),
              trailer: trailer)
  end

  def core_fields(rng)
    genre = Catalog.weighted_genre(rng)
    series = rng.rand < SERIES_SHARE
    year = series ? rng.rand(2008..2026) : (rng.rand < 0.75 ? rng.rand(2008..2026) : rng.rand(1972..2007))
    cast = Array.new(rng.rand(2..5)) { rng.rand < 0.06 ? Faker::MovieStore.stage_name : Faker::MovieStore.person }.uniq
    hero, rival = Faker::MovieStore.character, Faker::MovieStore.character
    {
      kind: series ? :series : :movie,
      genre: genre,
      genre_name: Faker::MovieStore.genre_name(genre),
      title: Faker::MovieStore.title(genre: genre),
      year: year,
      cast: cast,
      director: Faker::MovieStore.person,
      runtime: series ? rng.rand(38..62) : rng.rand(82..172),
      seasons: series ? rng.rand(1..7) : nil,
      episodes: series ? rng.rand(6..13) : nil,
      age_rating: age_rating(genre, rng),
      badges: badges(year, rng),
      plot: Faker::MovieStore.plot(genre: genre, context: { hero: hero, rival: rival, city: Faker::Address.city }),
      score: (rng.rand(25..95) + rng.rand(0..5)) / 10.0
    }
  end

  def age_rating(genre, rng)
    from, to = Catalog.genres.dig(genre, "ratings")
    ratings = region.age_ratings
    ratings[rng.rand(from..[to, ratings.size - 1].min)]
  end

  def badges(year, rng)
    list = []
    list << :top10 if rng.rand < 0.12
    list << :new if year >= 2025 && rng.rand < 0.6
    list << :award if rng.rand < 0.08
    list << :exclusive if rng.rand < 0.07
    list << :uhd if rng.rand < 0.2
    list.first(2)
  end

  # Fractional averages are realised probabilistically: 2.3 -> 2 or 3, with P(3) = 0.3.
  def average_count(average, rng)
    whole = average.floor
    whole + (rng.rand < (average - whole) ? 1 : 0)
  end

  def build_reviews(core, stream)
    count = with_rng(stream.call("reviews")) { |rng| average_count(reviews, rng) }
    Array.new(count) do |k|
      # Every review has its own stream, so review #k never changes when the count does.
      with_faker(stream.call("review:#{k}")) { |rng| review(core, rng) }
    end
  end

  def review(core, rng)
    roll = core[:score] + rng.rand(-2.5..2.5)
    sentiment = roll >= 6.5 ? "positive" : (roll >= 4.5 ? "mixed" : "negative")
    actors = core[:cast].shuffle(random: rng)
    context = { title: core[:title], actor: actors[0], actor2: actors[1] || actors[0] }
    Review.new(author: Faker::MovieStore.person, publication: Faker::MovieStore.publication,
               text: Faker::MovieStore.review(sentiment: sentiment, context: context), sentiment: sentiment)
  end

  def with_rng(seed)
    yield Random.new(seed)
  end

  def with_faker(seed)
    rng = Random.new(seed)
    previous = [Faker::Config.random, Faker::Config.own_locale]
    Faker::Config.random = rng
    Faker::Config.locale = region.faker_locale
    yield rng
  ensure
    Faker::Config.random, Faker::Config.locale = previous
  end
end
