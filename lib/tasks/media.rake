require "open-uri"
require "open3"
require "json"
require "fileutils"

# Builds the trailer media library from free-license Mixkit footage, music and sound effects.
#
#   bin/rails media:fetch          # everything
#   bin/rails media:clips          # footage only
#   bin/rails media:audio          # music + sfx only
#
# Sources are configured in config/media/sources.yml. Files are normalised with ffmpeg
# into public/media and described by config/media/clips.yml and config/media/audio.yml.
module MediaFetch
  ROOT = Rails.root.join("public/media")
  RAW = Rails.root.join("tmp/media")
  UA = "Mozilla/5.0 (Macintosh) ReelForge media fetcher"
  CLIP_SECONDS = 5.0
  MUSIC_SECONDS = 11.0
  SFX_SECONDS = 4.0

  module_function

  def sources
    @sources ||= YAML.load_file(Rails.root.join("config/media/sources.yml"))
  end

  def page(path)
    URI.open("https://mixkit.co/#{path}", "User-Agent" => UA, read_timeout: 30).read
  rescue OpenURI::HTTPError => e
    warn "  skip #{path}: #{e.message}"
    ""
  end

  # [{id:, title:, url:}] for every video card on a Mixkit tag page.
  def video_items(tag)
    doc = Nokogiri::HTML(page("free-stock-video/#{tag}/"))
    doc.css(".item-grid-card").filter_map do |card|
      src = card.at_css("video")&.[]("src")
      next unless src&.end_with?("-360.mp4")

      { id: src[%r{videos/(\d+)/}, 1], title: card.at_css("img")&.[]("alt").to_s.delete_suffix("."), url: src }
    end
  end

  # Audio items come from the JSON-LD block of music / sound effect pages.
  def audio_items(path)
    html = page(path)
    items = html.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).flat_map do |(json)|
      collect_audio(JSON.parse(json))
    rescue JSON::ParserError
      []
    end
    items += sfx_cards(html) if items.empty?
    items.uniq { |i| i[:url] }
  end

  # Sound effect pages have no JSON-LD; the preview URL sits on each card's audio player.
  def sfx_cards(html)
    Nokogiri::HTML(html).css(".item-grid-card").filter_map do |card|
      player = card.at_css("[data-audio-player-preview-url-value]") or next
      { id: player["data-audio-player-item-id-value"], title: card.at_css(".item-grid-card__title")&.text&.strip,
        artist: nil, url: player["data-audio-player-preview-url-value"] }
    end
  end

  def collect_audio(node)
    case node
    when Array then node.flat_map { |n| collect_audio(n) }
    when Hash
      url = node["url"] || node["contentUrl"]
      own = url.to_s.match?(/\.(mp3|wav)\z/) ? [{ id: url[%r{/(\d+)/[^/]+\z}, 1] || File.basename(url, ".*"), title: node["name"], artist: node["byArtist"].is_a?(String) ? node["byArtist"] : nil, url: url }] : []
      own + node.values.flat_map { |v| collect_audio(v) }
    else []
    end
  end

  def download(url, file)
    return file if File.size?(file)

    FileUtils.mkdir_p(File.dirname(file))
    File.binwrite(file, URI.open(url, "User-Agent" => UA, read_timeout: 120).read)
    file
  end

  def run(*cmd)
    out, status = Open3.capture2e(*cmd)
    raise "#{cmd.first} failed: #{out.lines.last(3).join}" unless status.success?

    out
  end

  def probe(file)
    json = JSON.parse(run("ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", file.to_s))
    video = json["streams"].find { |s| s["codec_type"] == "video" }
    { duration: json.dig("format", "duration").to_f, width: video&.[]("width"), height: video&.[]("height") }
  end

  # The loudest window of a track, measured with ffmpeg's EBU R128 momentary loudness.
  def loudest_window(file, length)
    out = run("ffmpeg", "-hide_banner", "-nostats", "-i", file.to_s, "-af", "ebur128=peak=none", "-f", "null", "-")
    points = out.scan(/t:\s*([\d.]+)\s+TARGET.*?M:\s*(-?[\d.]+|-inf)/).map { |t, m| [t.to_f, m == "-inf" ? -70.0 : m.to_f] }
    return 0.0 if points.size < 2

    step = points[1][0] - points[0][0]
    width = (length / step).round
    best = (0..[points.size - width, 0].max).max_by { |i| points[i, width].sum { |_, m| m } }
    [points[best][0] - 0.5, 0].max
  end

  def clips
    config = sources["clips"]
    raw = {}
    chosen = Hash.new { |h, k| h[k] = [] }

    config["genres"].each do |genre, spec|
      excluded = Regexp.union((spec["exclude"] + config["exclude_everywhere"]).map { |w| /\b#{Regexp.escape(w)}/i })
      per_tag = spec["tags"].map { |tag| video_items(tag).reject { |v| v[:title].match?(excluded) } }
      # Round-robin over tags so every genre gets a mix of subjects.
      until chosen[genre].size >= config["per_genre"] || per_tag.all?(&:empty?)
        per_tag.each do |queue|
          item = queue.shift or next
          next if chosen[genre].any? { |c| c[:id] == item[:id] }

          chosen[genre] << item
          raw[item[:id]] ||= item.merge(genres: [])
          raw[item[:id]][:genres] |= [genre]
          break if chosen[genre].size >= config["per_genre"]
        end
      end
      puts "#{genre}: #{chosen[genre].size} clips"
    end

    manifest = raw.values.filter_map.with_index do |item, n|
      print "\r  encoding #{n + 1}/#{raw.size}"
      encode_clip(item)
    rescue => e
      warn "\n  #{item[:id]}: #{e.message}"
      nil
    end
    File.write(Rails.root.join("config/media/clips.yml"), manifest.to_yaml)
    puts "\n#{manifest.size} clips -> config/media/clips.yml"
  end

  def encode_clip(item)
    src = download(item[:url], RAW.join("clips/#{item[:id]}.mp4"))
    info = probe(src)
    return nil if info[:height].to_i > info[:width].to_i # portrait footage does not fit a trailer

    start = [[info[:duration] * 0.2, info[:duration] - CLIP_SECONDS - 0.2].min, 0].max.round(2)
    length = [CLIP_SECONDS, info[:duration] - start].min.round(2)
    out = ROOT.join("clips/#{item[:id]}.mp4")
    FileUtils.mkdir_p(out.dirname)
    unless File.size?(out)
      run("ffmpeg", "-y", "-v", "error", "-ss", start.to_s, "-t", length.to_s, "-i", src.to_s,
          "-vf", "scale=640:360:force_original_aspect_ratio=increase,crop=640:360,fps=24,format=yuv420p",
          "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "29", "-g", "12", "-movflags", "+faststart", out.to_s)
      run("ffmpeg", "-y", "-v", "error", "-ss", "1.2", "-i", out.to_s, "-frames:v", "1", "-q:v", "4",
          ROOT.join("clips/#{item[:id]}.jpg").to_s)
    end
    { "id" => "c#{item[:id]}", "file" => "clips/#{item[:id]}.mp4", "thumb" => "clips/#{item[:id]}.jpg",
      "duration" => probe(out)[:duration].round(2), "title" => item[:title], "genres" => item[:genres],
      "source" => "https://mixkit.co/free-stock-video/", "license" => "Mixkit Stock Video Free License" }
  end

  def audio
    entries = []
    sources.dig("music", "genres").each do |genre, tags|
      items = tags.flat_map { |t| audio_items("free-stock-music/tag/#{t}/") }.uniq { |i| i[:url] }
      taken = entries.select { |e| e["kind"] == "music" && e["moods"].include?(genre) }.size
      items.each do |item|
        break if taken >= sources.dig("music", "per_genre")

        if (existing = entries.find { |e| e["url"] == item[:url] })
          existing["moods"] |= [genre]
        else
          entry = encode_audio(item, "music", MUSIC_SECONDS) or next
          entries << entry.merge("moods" => [genre])
        end
        taken += 1
      end
      puts "music #{genre}: #{taken}"
    end
    sources.dig("sfx", "kinds").each do |kind, tags|
      items = tags.flat_map { |t| audio_items("free-sound-effects/#{t}/") }.uniq { |i| i[:url] }
      items.first(sources.dig("sfx", "per_kind")).each do |item|
        entry = encode_audio(item, "sfx", SFX_SECONDS) and entries << entry.merge("moods" => [kind])
      end
      puts "sfx #{kind}: #{entries.count { |e| e["kind"] == "sfx" && e["moods"] == [kind] }}"
    end
    File.write(Rails.root.join("config/media/audio.yml"), entries.map { |e| e.except("url") }.to_yaml)
    puts "#{entries.size} audio files -> config/media/audio.yml"
  end

  def encode_audio(item, kind, seconds)
    src = download(item[:url], RAW.join("#{kind}/#{item[:id]}#{File.extname(item[:url])}"))
    duration = probe(src)[:duration]
    start = kind == "music" ? loudest_window(src, seconds) : 0
    length = [seconds, duration - start].min
    out = ROOT.join("#{kind}/#{item[:id]}.mp3")
    FileUtils.mkdir_p(out.dirname)
    unless File.size?(out)
      fade = kind == "music" ? 1.5 : 0.6
      run("ffmpeg", "-y", "-v", "error", "-ss", start.to_s, "-t", length.to_s, "-i", src.to_s,
          "-af", "afade=t=in:d=0.05,afade=t=out:st=#{[length - fade, 0].max}:d=#{fade},loudnorm=I=-16:TP=-1.5",
          "-ac", "2", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", kind == "music" ? "112k" : "96k", out.to_s)
    end
    { "id" => "#{kind[0]}#{item[:id]}", "kind" => kind, "file" => "#{kind}/#{item[:id]}.mp3", "url" => item[:url],
      "duration" => probe(out)[:duration].round(2), "title" => item[:title], "artist" => item[:artist],
      "license" => "Mixkit #{kind == "music" ? "Stock Music" : "Sound Effects"} Free License" }
  rescue => e
    warn "  #{item[:url]}: #{e.message}"
    nil
  end
end

namespace :media do
  desc "Download and normalise trailer footage"
  task clips: :environment do
    MediaFetch.clips
  end

  desc "Download and normalise trailer music and sound effects"
  task audio: :environment do
    MediaFetch.audio
  end

  desc "Build the whole trailer media library"
  task fetch: %i[clips audio]
end

namespace :media do
  desc "Download the trailer fonts as TTF files for the ffmpeg exporter"
  task fonts: :environment do
    dir = Rails.root.join("vendor/fonts")
    FileUtils.mkdir_p(dir)
    TrailerFonts.all.each do |font|
      weight = font["weights"].max
      css = URI.open("https://fonts.googleapis.com/css2?family=#{font["family"].tr(" ", "+")}:wght@#{weight}",
                     "User-Agent" => "curl/8.0").read
      url = css[/src: url\(([^)]+)\)/, 1] or next warn("no font url for #{font["family"]}")
      File.binwrite(dir.join("#{font["family"]}.ttf"), URI.open(url).read)
      puts font["family"]
    end
  end
end
