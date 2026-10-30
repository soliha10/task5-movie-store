module MediaLibraryBuilder
  class FontDownloader
    FONT_DIRECTORY = Rails.root.join("vendor/fonts")
    TRUETYPE_USER_AGENT = "curl/8.0"
    FONT_URL = /src: url\(([^)]+)\)/

    def download_all
      FileUtils.mkdir_p(FONT_DIRECTORY)
      TrailerFonts.all.each { |font| download(font) }
    end

    private

    def download(font)
      stylesheet_url = "#{TrailerFonts::GOOGLE_FONTS_URL}?family=#{font["family"].tr(" ", "+")}:wght@#{font["weights"].max}"
      stylesheet = URI.open(stylesheet_url, "User-Agent" => TRUETYPE_USER_AGENT).read
      font_url = stylesheet[FONT_URL, 1]
      return warn("no font url for #{font["family"]}") unless font_url

      File.binwrite(FONT_DIRECTORY.join("#{font["family"]}.ttf"), URI.open(font_url).read)
      puts font["family"]
    end
  end
end
