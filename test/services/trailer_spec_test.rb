require "test_helper"

class TrailerSpecTest < ActiveSupport::TestCase
  def trailer(seed: 1, index: 1)
    build_generator(seed: seed).movie(index).trailer
  end

  test "trailers are reproducible and differ between seeds" do
    assert_equal trailer, trailer
    refute_equal trailer[:shots], trailer(seed: 2)[:shots]
  end

  test "trailers do not depend on likes or reviews" do
    assert_equal build_generator(seed: 5, likes: 0, reviews: 0).movie(3).trailer,
                 build_generator(seed: 5, likes: 9, reviews: 9).movie(3).trailer
  end

  test "every trailer shows the movie title and fits 7-10 seconds" do
    build_generator(locale: "de-DE", seed: 99).page(1).each do |movie|
      spec = movie.trailer
      assert spec[:texts].any? { |text_card| text_card[:title] && text_card[:text].casecmp?(movie.title) }, movie.title
      assert_in_delta 8.5, spec[:duration], 1.5
      assert_in_delta spec[:duration], spec[:shots].sum { |shot| shot[:duration] }, 0.05
    end
  end
end
