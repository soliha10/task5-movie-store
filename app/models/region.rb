class Region
  CONFIG_DIRECTORY = "config/regions"
  DEFAULT_CODE = "en-US"
  DEFAULT_ORDER = 99

  attr_reader :code, :name, :faker_locale, :html_lang, :order, :age_ratings, :labels

  def self.all
    @all ||= Dir[Rails.root.join(CONFIG_DIRECTORY, "*.yml")]
               .map { |path| new(YamlConfig.load(path)) }
               .sort_by { |region| [region.order, region.code] }
  end

  def self.find(code)
    all.find { |region| region.code == code } || all.find { |region| region.code == DEFAULT_CODE } || all.first
  end

  def initialize(settings)
    @code = settings.fetch("code")
    @name = settings.fetch("name")
    @faker_locale = settings.fetch("faker_locale")
    @html_lang = settings.fetch("html_lang", code)
    @order = settings.fetch("order", DEFAULT_ORDER)
    @age_ratings = settings.fetch("age_ratings")
    @labels = settings.fetch("labels")
  end

  def label(*path)
    labels.dig(*path.map(&:to_s)) || path.last.to_s.humanize
  end

  def seed_salt
    Seeding.salt(code)
  end
end
