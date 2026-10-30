# Language-neutral configuration under config/catalog.
module Catalog
  module_function

  def genres
    @genres ||= YAML.load_file(Rails.root.join("config/catalog/genres.yml"))
  end

  def grades
    @grades ||= YAML.load_file(Rails.root.join("config/catalog/grades.yml"))
  end

  def genre_ids
    genres.keys
  end

  def weighted_genre(rng)
    total = genres.sum { |_, g| g["weight"] }
    roll = rng.rand(total)
    genres.each do |id, g|
      return id if (roll -= g["weight"]).negative?
    end
  end
end
