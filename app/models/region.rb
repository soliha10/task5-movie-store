# A language/region loaded from config/regions/*.yml.
class Region
  DIR = Rails.root.join("config/regions")
  DEFAULT = "en-US"

  attr_reader :code, :name, :faker_locale, :html_lang, :age_ratings, :labels

  def self.all
    @all ||= Dir[DIR.join("*.yml")].map { |f| new(YAML.load_file(f)) }.sort_by { |r| [r.order, r.code] }
  end

  def self.find(code)
    all.find { |r| r.code == code } || all.find { |r| r.code == DEFAULT } || all.first
  end

  def initialize(data)
    @code = data.fetch("code")
    @name = data.fetch("name")
    @faker_locale = data.fetch("faker_locale")
    @html_lang = data.fetch("html_lang", code)
    @order = data.fetch("order", 99)
    @age_ratings = data.fetch("age_ratings")
    @labels = data.fetch("labels")
  end

  attr_reader :order

  def label(*path)
    labels.dig(*path.map(&:to_s)) || path.last.to_s.humanize
  end

  def salt
    Seeding.salt(code)
  end
end
