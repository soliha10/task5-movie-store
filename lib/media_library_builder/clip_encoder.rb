module MediaLibraryBuilder
  class ClipEncoder
    CLIP_SECONDS = 5.0
    START_SHARE = 0.2
    END_MARGIN_SECONDS = 0.2
    VIDEO_FILTER = "scale=640:360:force_original_aspect_ratio=increase,crop=640:360,fps=24,format=yuv420p"
    ENCODING_ARGS = %w[-an -c:v libx264 -preset slow -crf 29 -g 12 -movflags +faststart].freeze
    THUMBNAIL_SECOND = 1.2
    THUMBNAIL_QUALITY = 4
    SOURCE_PAGE = "https://mixkit.co/free-stock-video/"
    LICENSE = "Mixkit Stock Video Free License"

    def initialize(clip)
      @clip = clip
    end

    def encode
      source_path = MediaTools.download(@clip[:url], MediaLibraryBuilder::DOWNLOAD_DIRECTORY.join("clips/#{@clip[:id]}.mp4"))
      source_info = MediaTools.media_info(source_path)
      return nil if portrait?(source_info)

      write_clip(source_path, source_info) unless File.size?(video_path)
      manifest_entry
    end

    private

    def portrait?(source_info)
      source_info[:height].to_i > source_info[:width].to_i
    end

    def write_clip(source_path, source_info)
      FileUtils.mkdir_p(video_path.dirname)
      start_second = [[source_info[:duration] * START_SHARE, source_info[:duration] - CLIP_SECONDS - END_MARGIN_SECONDS].min, 0].max.round(2)
      length = [CLIP_SECONDS, source_info[:duration] - start_second].min.round(2)
      MediaTools.run_command("ffmpeg", "-y", "-v", "error", "-ss", start_second, "-t", length, "-i", source_path,
                             "-vf", VIDEO_FILTER, *ENCODING_ARGS, video_path)
      MediaTools.run_command("ffmpeg", "-y", "-v", "error", "-ss", THUMBNAIL_SECOND, "-i", video_path,
                             "-frames:v", "1", "-q:v", THUMBNAIL_QUALITY, thumbnail_path)
    end

    def video_path
      MediaLibraryBuilder::PUBLIC_DIRECTORY.join("clips/#{@clip[:id]}.mp4")
    end

    def thumbnail_path
      MediaLibraryBuilder::PUBLIC_DIRECTORY.join("clips/#{@clip[:id]}.jpg")
    end

    def manifest_entry
      { "id" => "c#{@clip[:id]}", "file" => "clips/#{@clip[:id]}.mp4", "thumb" => "clips/#{@clip[:id]}.jpg",
        "duration" => MediaTools.media_info(video_path)[:duration].round(2), "title" => @clip[:title],
        "genres" => @clip[:genres], "source" => SOURCE_PAGE, "license" => LICENSE }
    end
  end
end
