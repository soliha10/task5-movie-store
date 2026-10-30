require "test_helper"

class MovieGeneratorTest < ActiveSupport::TestCase
  def movie_without_counts(movie)
    movie.to_h.except(:likes, :reviews)
  end

  test "same parameters always produce identical data" do
    assert_equal build_generator.page(3).map(&:to_h), build_generator.page(3).map(&:to_h)
  end

  test "single record lookup matches the page" do
    assert_equal build_generator.page(2)[4].to_h, build_generator.movie(25).to_h
  end

  test "changing likes only changes likes" do
    without_likes = build_generator(likes: 0).page(1)
    with_likes = build_generator(likes: 7.4).page(1)
    assert_equal without_likes.map { |movie| movie_without_counts(movie) }, with_likes.map { |movie| movie_without_counts(movie) }
    assert_equal without_likes.map(&:reviews), with_likes.map(&:reviews)
    assert without_likes.all? { |movie| movie.likes.zero? }
  end

  test "changing review count keeps existing reviews" do
    two_reviews = build_generator(reviews: 2).page(1)
    three_reviews = build_generator(reviews: 3).page(1)
    two_reviews.zip(three_reviews).each do |fewer, more|
      assert_equal movie_without_counts(fewer), movie_without_counts(more)
      assert_equal 2, fewer.reviews.size
      assert_equal 3, more.reviews.size
      assert_equal fewer.reviews, more.reviews.first(2)
    end
  end

  test "fractional averages are probabilistic" do
    generator = build_generator(likes: 0.5)
    like_counts = (1..100).flat_map { |page_number| generator.page(page_number).map(&:likes) }
    assert_equal [0, 1], like_counts.uniq.sort
    assert_in_delta 0.5, like_counts.sum.fdiv(like_counts.size), 0.05
    assert build_generator(likes: 10).page(1).all? { |movie| movie.likes == 10 }
  end

  test "seed and region change the content" do
    default_titles = build_generator.page(1).map(&:title)
    refute_equal default_titles, build_generator(seed: 42).page(1).map(&:title)
    refute_equal default_titles, build_generator(locale: Region.all.last.code).page(1).map(&:title)
  end

  test "pages differ and indexes are sequential" do
    first_page = build_generator.page(1)
    second_page = build_generator.page(2)
    assert_equal (1..20).to_a, first_page.map(&:index)
    assert_equal (21..40).to_a, second_page.map(&:index)
    refute_equal first_page.map(&:title), second_page.map(&:title)
  end

  test "every region generates without missing translations" do
    Region.all.each do |region|
      movies = build_generator(locale: region.code, reviews: 3).page(1)
      generated_text = movies.flat_map { |movie| [movie.title, movie.plot, *movie.cast, *movie.reviews.map(&:text)] }.join(" ")
      refute_match(/translation missing|#\{/, generated_text, region.code)
    end
  end

  test "large 64-bit seeds work" do
    assert_equal 20, build_generator(seed: Seeding.parse("18446744073709551615")).page(9_999).size
  end
end
