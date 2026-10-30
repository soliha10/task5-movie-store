module MediaLibraryBuilder
  class AudioCollector
    def initialize(sources = MediaLibraryBuilder.sources)
      @music_settings = sources["music"]
      @effect_settings = sources["sfx"]
      @entries = []
    end

    def collect
      @music_settings["genres"].each { |genre, tags| collect_music(genre, tags) }
      @effect_settings["kinds"].each { |kind, tags| collect_sound_effects(kind, tags) }
      MediaLibraryBuilder.write_manifest("audio", @entries.map { |entry| entry.except("url") })
    end

    private

    def collect_music(genre, tags)
      tracks = tags.flat_map { |tag| MixkitClient.music(tag) }.uniq { |track| track[:url] }
      taken = @entries.count { |entry| entry["kind"] == "music" && entry["moods"].include?(genre) }
      tracks.each do |track|
        break if taken >= @music_settings["per_genre"]

        taken += 1 if add_music(track, genre)
      end
      puts "music #{genre}: #{taken}"
    end

    def add_music(track, genre)
      existing = @entries.find { |entry| entry["url"] == track[:url] }
      return existing["moods"] |= [genre] if existing

      entry = AudioEncoder.new(track, "music").encode
      entry && @entries << entry.merge("moods" => [genre])
    end

    def collect_sound_effects(kind, tags)
      effects = tags.flat_map { |tag| MixkitClient.sound_effects(tag) }.uniq { |effect| effect[:url] }
      effects.first(@effect_settings["per_kind"]).each do |effect|
        entry = AudioEncoder.new(effect, "sfx").encode
        @entries << entry.merge("moods" => [kind]) if entry
      end
      puts "sfx #{kind}: #{@entries.count { |entry| entry["kind"] == "sfx" && entry["moods"] == [kind] }}"
    end
  end
end
