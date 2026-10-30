class MoviesController < ApplicationController
  include GenerationParams

  def index
    @movies = generator.page(state.page)
  end

  def batch
    @movies = generator.page(state.page)
    render layout: false
  end
end
