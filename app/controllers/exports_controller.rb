class ExportsController < ApplicationController
  include GenerationParams

  def show
    send_data TrailerArchive.new(current_page_movies).to_zip, type: "application/zip", filename: archive_name
  end

  private

  def archive_name
    "trailers-#{state.region.code}-#{state.seed}-page#{state.page}.zip"
  end
end
