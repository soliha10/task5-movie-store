class PagesController < ApplicationController
  def credits
    @clips = MediaLibrary.clips
    @audio = MediaLibrary.audio
  end
end
