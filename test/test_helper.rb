ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module GeneratorTestHelpers
  DEFAULT_SEED = 58_933_423

  def build_generator(locale: "en-US", seed: DEFAULT_SEED, likes: 3.7, reviews: 2.3)
    MovieGenerator.new(region: Region.find(locale), seed: seed, likes: likes, reviews: reviews)
  end
end

module ActiveSupport
  class TestCase
    include GeneratorTestHelpers

    parallelize(workers: :number_of_processors)
  end
end
