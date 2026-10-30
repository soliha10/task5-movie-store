require "test_helper"

class MovieGeneratorTest < ActiveSupport::TestCase
  def generator(locale: "en-US", seed: 58_933_423, likes: 3.7, reviews: 2.3)
    MovieGenerator.new(region: Region.find(locale), seed: seed, likes: likes, reviews: reviews)
  end

  def core(movie)
    movie.to_h.except(:likes, :reviews)
  end

  test "same parameters always produce identical data" do
    assert_equal generator.page(3).map(&:to_h), generator.page(3).map(&:to_h)
  end

  test "single record lookup matches the page" do
    assert_equal generator.page(2)[4].to_h, generator.movie(25).to_h
  end

  test "changing likes only changes likes" do
    a = generator(likes: 0).page(1)
    b = generator(likes: 7.4).page(1)
    assert_equal a.map { core(_1) }, b.map { core(_1) }
    assert_equal a.map(&:reviews), b.map(&:reviews)
    assert a.all? { _1.likes.zero? }
  end

  test "changing review count keeps existing reviews" do
    few = generator(reviews: 2).page(1)
    more = generator(reviews: 3).page(1)
    few.zip(more).each do |a, b|
      assert_equal core(a), core(b)
      assert_equal 2, a.reviews.size
      assert_equal 3, b.reviews.size
      assert_equal a.reviews, b.reviews.first(2)
    end
  end

  test "fractional averages are probabilistic" do
    gen = generator(likes: 0.5)
    likes = (1..100).flat_map { gen.page(_1).map(&:likes) }
    assert_equal [0, 1], likes.uniq.sort
    assert_in_delta 0.5, likes.sum.fdiv(likes.size), 0.05
    assert generator(likes: 10).page(1).all? { _1.likes == 10 }
  end

  test "seed and region change the content" do
    base = generator.page(1).map(&:title)
    refute_equal base, generator(seed: 42).page(1).map(&:title)
    refute_equal base, generator(locale: Region.all.last.code).page(1).map(&:title)
  end

  test "pages differ and indexes are sequential" do
    p1, p2 = generator.page(1), generator.page(2)
    assert_equal (1..20).to_a, p1.map(&:index)
    assert_equal (21..40).to_a, p2.map(&:index)
    refute_equal p1.map(&:title), p2.map(&:title)
  end

  test "every region generates without missing translations" do
    Region.all.each do |region|
      movies = generator(locale: region.code, reviews: 3).page(1)
      text = movies.flat_map { [_1.title, _1.plot, *_1.cast, *_1.reviews.map(&:text)] }.join(" ")
      refute_match(/translation missing|#\{/, text, region.code)
    end
  end

  test "large 64-bit seeds work" do
    assert_equal 20, generator(seed: Seeding.parse("18446744073709551615")).page(9_999).size
  end
end
