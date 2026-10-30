module GoldenOutput
  REGIONS = %w[en-US de-DE uk-UA].freeze
  SEEDS = [58_933_423, 1, 18_446_744_073_709_551_615].freeze
  PAGES = [1, 7].freeze
  LIKES = 3.7
  REVIEWS = 2.3
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/golden_output.json")

  module_function

  def generate
    REGIONS.product(SEEDS, PAGES).to_h do |region_code, seed, page_number|
      generator = MovieGenerator.new(region: Region.find(region_code), seed: seed, likes: LIKES, reviews: REVIEWS)
      ["#{region_code}/#{seed}/#{page_number}", generator.page(page_number).map { |movie| serialize(movie) }]
    end
  end

  def serialize(movie)
    JSON.parse(movie.to_h.merge(reviews: movie.reviews.map(&:to_h)).to_json)
  end

  def write
    File.write(FIXTURE_PATH, JSON.pretty_generate(generate))
  end
end
