require "test_helper"

class TrailerSpecTest < ActiveSupport::TestCase
  def trailer(seed: 1, index: 1, locale: "en-US")
    MovieGenerator.new(region: Region.find(locale), seed: seed).movie(index).trailer
  end

  test "trailers are reproducible and differ between seeds" do
    assert_equal trailer, trailer
    refute_equal trailer[:shots], trailer(seed: 2)[:shots]
  end

  test "trailers do not depend on likes or reviews" do
    a = MovieGenerator.new(region: Region.find("en-US"), seed: 5, likes: 0, reviews: 0).movie(3).trailer
    b = MovieGenerator.new(region: Region.find("en-US"), seed: 5, likes: 9, reviews: 9).movie(3).trailer
    assert_equal a, b
  end

  test "every trailer shows the movie title and fits 7-10 seconds" do
    gen = MovieGenerator.new(region: Region.find("de-DE"), seed: 99)
    gen.page(1).each do |movie|
      spec = movie.trailer
      assert spec[:texts].any? { |t| t[:title] && t[:text].casecmp?(movie.title) }, movie.title
      assert_in_delta 8.5, spec[:duration], 1.5
      assert_in_delta spec[:duration], spec[:shots].sum { _1[:duration] }, 0.05
    end
  end
end
