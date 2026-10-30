class GenerationState < Data.define(:region, :seed, :likes, :reviews, :view, :page)
  DEFAULT_SEED = 58_933_423
  DEFAULT_LIKES = 3.7
  DEFAULT_REVIEWS = 2.3
  AVERAGE_RANGE = (0.0..10.0)
  AVERAGE_PRECISION = 1
  VIEWS = %w[table gallery].freeze
  FIRST_PAGE = 1

  def self.from_params(params)
    new(
      region: Region.find(params[:locale]),
      seed: params[:seed].present? ? Seeding.parse(params[:seed]) : DEFAULT_SEED,
      likes: parse_average(params[:likes], DEFAULT_LIKES),
      reviews: parse_average(params[:reviews], DEFAULT_REVIEWS),
      view: VIEWS.include?(params[:view]) ? params[:view] : VIEWS.first,
      page: [params[:page].to_i, FIRST_PAGE].max
    )
  end

  def self.parse_average(value, default)
    return default if value.blank?

    Float(value, exception: false)&.clamp(AVERAGE_RANGE)&.round(AVERAGE_PRECISION) || default
  end

  def gallery?
    view == "gallery"
  end

  def first_page?
    page == FIRST_PAGE
  end

  def query(overrides = {})
    { locale: region.code, seed: seed.to_s, likes: likes, reviews: reviews, view: view }.merge(overrides)
  end

  def movie_generator
    MovieGenerator.new(region: region, seed: seed, likes: likes, reviews: reviews)
  end
end
