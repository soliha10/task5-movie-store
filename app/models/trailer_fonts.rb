module TrailerFonts
  GOOGLE_FONTS_URL = "https://fonts.googleapis.com/css2"

  module_function

  def all
    @all ||= YamlConfig.load("config/catalog/fonts.yml").uniq { |font| font["family"] }
  end

  def for_genre(genre)
    all.select { |font| font["moods"].include?(genre.to_s) }.presence || all
  end

  def stylesheet_url
    families = all.map { |font| "family=#{font["family"].tr(" ", "+")}:wght@#{font["weights"].join(";")}" }
    "#{GOOGLE_FONTS_URL}?#{families.join("&")}&display=swap"
  end
end
