class TrailersController < ApplicationController
  include GenerationParams

  def show
    render json: generator.movie(params[:index].to_i).trailer
  end
end
