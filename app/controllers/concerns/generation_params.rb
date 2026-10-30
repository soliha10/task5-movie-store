# Reads the generation parameters shared by every endpoint.
module GenerationParams
  extend ActiveSupport::Concern

  DEFAULT_SEED = 58_933_423

  included do
    helper_method :state
  end

  def state
    @state ||= begin
      region = Region.find(params[:locale])
      seed = params[:seed].present? ? Seeding.parse(params[:seed]) : DEFAULT_SEED
      likes = number_param(:likes, 3.7)
      reviews = number_param(:reviews, 2.3)
      view = params[:view] == "gallery" ? "gallery" : "table"
      page = [params[:page].to_i, 1].max
      State.new(region:, seed:, likes:, reviews:, view:, page:)
    end
  end

  def generator
    @generator ||= MovieGenerator.new(region: state.region, seed: state.seed, likes: state.likes, reviews: state.reviews)
  end

  private

  def number_param(key, default)
    return default if params[key].blank?

    Float(params[key], exception: false)&.clamp(0.0, 10.0)&.round(1) || default
  end

  State = Data.define(:region, :seed, :likes, :reviews, :view, :page) do
    def query(overrides = {})
      { locale: region.code, seed: seed.to_s, likes: likes, reviews: reviews, view: view }.merge(overrides)
    end
  end
end
