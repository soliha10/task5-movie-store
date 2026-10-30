module MediaLibrary
  module_function

  def clips
    @clips ||= load("clips")
  end

  def audio
    @audio ||= load("audio")
  end

  def clips_for(genre)
    @by_genre ||= {}
    @by_genre[genre] ||= clips.select { |c| Array(c["genres"]).include?(genre.to_s) }
  end

  def audio_for(kind, mood = nil)
    audio.select { |a| a["kind"] == kind && (mood.nil? || Array(a["moods"]).include?(mood.to_s)) }
  end

  def base_url
    ENV.fetch("MEDIA_BASE_URL", "/media")
  end

  def url(path)
    "#{base_url}/#{path}"
  end

  def load(name)
    file = Rails.root.join("config/media/#{name}.yml")
    File.exist?(file) ? YAML.load_file(file, aliases: true) : []
  end
end
