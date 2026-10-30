module MediaLibraryBuilder
  class AudioEncoder
    SETTINGS = {
      "music" => { seconds: 11.0, fade_out: 1.5, bitrate: "112k", license: "Mixkit Stock Music Free License" },
      "sfx" => { seconds: 4.0, fade_out: 0.6, bitrate: "96k", license: "Mixkit Sound Effects Free License" }
    }.freeze
    FADE_IN_SECONDS = 0.05
    LOUDNESS_FILTER = "loudnorm=I=-16:TP=-1.5"
    SAMPLE_RATE = 44_100

    def initialize(item, kind)
      @item = item
      @kind = kind
      @settings = SETTINGS.fetch(kind)
    end

    def encode
      source_path = MediaTools.download(@item[:url], MediaLibraryBuilder::DOWNLOAD_DIRECTORY.join("#{@kind}/#{@item[:id]}#{File.extname(@item[:url])}"))
      start_second = @kind == "music" ? MediaTools.loudest_window_start(source_path, @settings[:seconds]) : 0
      length = [@settings[:seconds], MediaTools.media_info(source_path)[:duration] - start_second].min
      write_audio(source_path, start_second, length) unless File.size?(output_path)
      manifest_entry
    rescue StandardError => error
      warn "  #{@item[:url]}: #{error.message}"
      nil
    end

    private

    def write_audio(source_path, start_second, length)
      FileUtils.mkdir_p(output_path.dirname)
      fade_out = @settings[:fade_out]
      fades = "afade=t=in:d=#{FADE_IN_SECONDS},afade=t=out:st=#{[length - fade_out, 0].max}:d=#{fade_out},#{LOUDNESS_FILTER}"
      MediaTools.run_command("ffmpeg", "-y", "-v", "error", "-ss", start_second, "-t", length, "-i", source_path,
                             "-af", fades, "-ac", "2", "-ar", SAMPLE_RATE, "-c:a", "libmp3lame", "-b:a", @settings[:bitrate], output_path)
    end

    def output_path
      MediaLibraryBuilder::PUBLIC_DIRECTORY.join("#{@kind}/#{@item[:id]}.mp3")
    end

    def manifest_entry
      { "id" => "#{@kind[0]}#{@item[:id]}", "kind" => @kind, "file" => "#{@kind}/#{@item[:id]}.mp3", "url" => @item[:url],
        "duration" => MediaTools.media_info(output_path)[:duration].round(2), "title" => @item[:title],
        "artist" => @item[:artist], "license" => @settings[:license] }
    end
  end
end
