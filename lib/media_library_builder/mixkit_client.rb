require "nokogiri"

module MediaLibraryBuilder
  module MixkitClient
    BASE_URL = "https://mixkit.co"
    PAGE_TIMEOUT = 30
    PREVIEW_VIDEO_SUFFIX = "-360.mp4"
    JSON_LD_BLOCK = %r{<script type="application/ld\+json">(.*?)</script>}m
    AUDIO_FILE = /\.(mp3|wav)\z/
    PREVIEW_URL_ATTRIBUTE = "data-audio-player-preview-url-value"
    ITEM_ID_ATTRIBUTE = "data-audio-player-item-id-value"

    module_function

    def videos(tag)
      Nokogiri::HTML(page("free-stock-video/#{tag}/")).css(".item-grid-card").filter_map do |card|
        video_url = card.at_css("video")&.[]("src")
        next unless video_url&.end_with?(PREVIEW_VIDEO_SUFFIX)

        { id: video_url[%r{videos/(\d+)/}, 1], title: card.at_css("img")&.[]("alt").to_s.delete_suffix("."), url: video_url }
      end
    end

    def music(tag)
      audio_items("free-stock-music/tag/#{tag}/")
    end

    def sound_effects(tag)
      audio_items("free-sound-effects/#{tag}/")
    end

    def audio_items(path)
      html = page(path)
      items = structured_audio(html).presence || audio_player_cards(html)
      items.uniq { |item| item[:url] }
    end

    def page(path)
      URI.open("#{BASE_URL}/#{path}", "User-Agent" => MediaTools::USER_AGENT, read_timeout: PAGE_TIMEOUT).read
    rescue OpenURI::HTTPError => error
      warn "  skip #{path}: #{error.message}"
      ""
    end

    def structured_audio(html)
      html.scan(JSON_LD_BLOCK).flat_map do |(json)|
        audio_nodes(JSON.parse(json))
      rescue JSON::ParserError
        []
      end
    end

    def audio_nodes(node)
      case node
      when Array then node.flat_map { |child| audio_nodes(child) }
      when Hash then [audio_node(node), *node.values.flat_map { |child| audio_nodes(child) }].compact
      else []
      end
    end

    def audio_node(node)
      url = node["url"] || node["contentUrl"]
      return unless url.to_s.match?(AUDIO_FILE)

      artist = node["byArtist"].is_a?(String) ? node["byArtist"] : nil
      { id: url[%r{/(\d+)/[^/]+\z}, 1] || File.basename(url, ".*"), title: node["name"], artist: artist, url: url }
    end

    def audio_player_cards(html)
      Nokogiri::HTML(html).css(".item-grid-card").filter_map do |card|
        player = card.at_css("[#{PREVIEW_URL_ATTRIBUTE}]") or next
        { id: player[ITEM_ID_ATTRIBUTE], title: card.at_css(".item-grid-card__title")&.text&.strip,
          artist: nil, url: player[PREVIEW_URL_ATTRIBUTE] }
      end
    end
  end
end
