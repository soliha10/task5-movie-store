class MoviesController < ApplicationController
  include GenerationParams

  def index
    @movies = generator.page(state.page)
  end

  # One gallery batch; used by the lazy turbo-frame at the end of the previous batch.
  def batch
    @movies = generator.page(state.page)
    render layout: false
  end
end
