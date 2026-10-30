require "open-uri"
require "open3"
require "json"
require "fileutils"

module MediaLibraryBuilder
  module MediaTools
    USER_AGENT = "Mozilla/5.0 (Macintosh) ReelForge media fetcher"
    DOWNLOAD_TIMEOUT = 120
    SILENCE_LOUDNESS = -70.0
    WINDOW_LEAD_SECONDS = 0.5
    LOUDNESS_POINT = /t:\s*([\d.]+)\s+TARGET.*?M:\s*(-?[\d.]+|-inf)/

    module_function

    def download(url, target_path)
      return target_path if File.size?(target_path)

      FileUtils.mkdir_p(File.dirname(target_path))
      File.binwrite(target_path, URI.open(url, "User-Agent" => USER_AGENT, read_timeout: DOWNLOAD_TIMEOUT).read)
      target_path
    end

    def run_command(*command)
      output, status = Open3.capture2e(*command.map(&:to_s))
      raise "#{command.first} failed: #{output.lines.last(3).join}" unless status.success?

      output
    end

    def media_info(path)
      info = JSON.parse(run_command("ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path))
      video_stream = info["streams"].find { |stream| stream["codec_type"] == "video" }
      { duration: info.dig("format", "duration").to_f, width: video_stream&.dig("width"), height: video_stream&.dig("height") }
    end

    def loudest_window_start(path, window_seconds)
      report = run_command("ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=none", "-f", "null", "-")
      points = report.scan(LOUDNESS_POINT).map { |time, loudness| [time.to_f, loudness == "-inf" ? SILENCE_LOUDNESS : loudness.to_f] }
      return 0.0 if points.size < 2

      points_per_window = (window_seconds / (points[1][0] - points[0][0])).round
      loudest_index = (0..[points.size - points_per_window, 0].max).max_by do |index|
        points[index, points_per_window].sum { |_time, loudness| loudness }
      end
      [points[loudest_index][0] - WINDOW_LEAD_SECONDS, 0].max
    end
  end
end
