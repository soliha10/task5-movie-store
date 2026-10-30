module Catalog
  module_function

  def genres
    @genres ||= YamlConfig.load("config/catalog/genres.yml")
  end

  def grades
    @grades ||= YamlConfig.load("config/catalog/grades.yml")
  end

  def genre_style(genre_id)
    genres.fetch(genre_id)
  end

  def weighted_genre(random)
    total_weight = genres.sum { |_genre_id, genre| genre["weight"] }
    remaining_weight = random.rand(total_weight)
    genres.each do |genre_id, genre|
      remaining_weight -= genre["weight"]
      return genre_id if remaining_weight.negative?
    end
  end
end
