module GenerationParams
  extend ActiveSupport::Concern

  included do
    helper_method :state
  end

  def state
    @state ||= GenerationState.from_params(params)
  end

  def generator
    @generator ||= state.movie_generator
  end

  def current_page_movies
    generator.page(state.page)
  end
end
