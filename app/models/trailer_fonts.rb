# Google Fonts used by the trailer typography (config/catalog/fonts.yml).
module TrailerFonts
  module_function

  def all
    @all ||= YAML.load_file(Rails.root.join("config/catalog/fonts.yml")).uniq { |f| f["family"] }
  end

  def for_genre(genre)
    matching = all.select { |f| f["moods"].include?(genre.to_s) }
    matching.presence || all
  end

  def stylesheet_url
    families = all.map do |f|
      "family=#{f["family"].tr(" ", "+")}:wght@#{f["weights"].join(";")}"
    end
    "https://fonts.googleapis.com/css2?#{families.join("&")}&display=swap"
  end
end
