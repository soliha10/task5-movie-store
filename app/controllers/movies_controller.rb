class MoviesController < ApplicationController
  include GenerationParams

  def index
    @movies = current_page_movies
  end

  def batch
    @movies = current_page_movies
    render layout: false
  end
end
