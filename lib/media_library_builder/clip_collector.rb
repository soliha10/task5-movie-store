module MediaLibraryBuilder
  class ClipCollector
    def initialize(settings = MediaLibraryBuilder.sources["clips"])
      @settings = settings
      @clips_by_id = {}
      @clips_by_genre = Hash.new { |hash, genre| hash[genre] = [] }
    end

    def collect
      @settings["genres"].each do |genre, genre_settings|
        fill_genre(genre, candidates_by_tag(genre_settings))
        puts "#{genre}: #{@clips_by_genre[genre].size} clips"
      end
      encode_all
    end

    private

    def candidates_by_tag(genre_settings)
      excluded_titles = excluded_title_pattern(genre_settings["exclude"] + @settings["exclude_everywhere"])
      genre_settings["tags"].map do |tag|
        MixkitClient.videos(tag).reject { |clip| clip[:title].match?(excluded_titles) }
      end
    end

    def excluded_title_pattern(words)
      Regexp.union(words.map { |word| /\b#{Regexp.escape(word)}/i })
    end

    def fill_genre(genre, candidate_queues)
      chosen = @clips_by_genre[genre]
      until genre_full?(chosen) || candidate_queues.all?(&:empty?)
        candidate_queues.each do |queue|
          clip = queue.shift or next
          next if chosen.any? { |chosen_clip| chosen_clip[:id] == clip[:id] }

          choose(genre, clip)
          break if genre_full?(chosen)
        end
      end
    end

    def genre_full?(chosen)
      chosen.size >= @settings["per_genre"]
    end

    def choose(genre, clip)
      @clips_by_genre[genre] << clip
      @clips_by_id[clip[:id]] ||= clip.merge(genres: [])
      @clips_by_id[clip[:id]][:genres] |= [genre]
    end

    def encode_all
      clips = @clips_by_id.values
      entries = clips.filter_map.with_index do |clip, clip_number|
        print "\r  encoding #{clip_number + 1}/#{clips.size}"
        ClipEncoder.new(clip).encode
      rescue StandardError => error
        warn "\n  #{clip[:id]}: #{error.message}"
        nil
      end
      puts
      MediaLibraryBuilder.write_manifest("clips", entries)
    end
  end
end
