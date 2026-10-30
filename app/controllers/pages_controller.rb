class PagesController < ApplicationController
  include GenerationParams

  def credits
    @clips = MediaLibrary.clips
    @music_tracks = MediaLibrary.audio_for("music")
    @sound_effects = MediaLibrary.audio_for("sfx")
  end
end
