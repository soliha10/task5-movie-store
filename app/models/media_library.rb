module MediaLibrary
  DEFAULT_BASE_URL = "/media"

  module_function

  def clips
    @clips ||= YamlConfig.load("config/media/clips.yml", fallback: [])
  end

  def audio
    @audio ||= YamlConfig.load("config/media/audio.yml", fallback: [])
  end

  def clips_for(genre)
    @clips_by_genre ||= {}
    @clips_by_genre[genre] ||= clips.select { |clip| Array(clip["genres"]).include?(genre.to_s) }
  end

  def audio_for(kind, mood = nil)
    audio.select do |track|
      track["kind"] == kind && (mood.nil? || Array(track["moods"]).include?(mood.to_s))
    end
  end

  def url(relative_path)
    "#{ENV.fetch("MEDIA_BASE_URL", DEFAULT_BASE_URL)}/#{relative_path}"
  end
end
