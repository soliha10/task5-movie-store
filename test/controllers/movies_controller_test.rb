require "test_helper"

class MoviesControllerTest < ActionDispatch::IntegrationTest
  test "table and gallery render for every region" do
    Region.all.each do |region|
      get root_path(locale: region.code, seed: 123)
      assert_response :success
      assert_select ".movie-row", 20
      get root_path(locale: region.code, seed: 123, view: "gallery")
      assert_select ".movie-card", 20
    end
  end

  test "pages continue numbering" do
    get root_path(seed: 1, page: 7)
    assert_select ".movie-row .idx-col", text: "121"
  end

  test "gallery batches chain into the next one" do
    get movies_batch_path(seed: 1, page: 3, view: "gallery")
    assert_response :success
    assert_select "turbo-frame#batch_3 .movie-card", 20
    assert_select "turbo-frame#batch_4[loading=lazy]"
  end

  test "trailer spec endpoint" do
    get movie_trailer_path(5, seed: 1)
    assert_response :success
    trailer_spec = response.parsed_body
    assert trailer_spec["duration"].positive?
    assert trailer_spec["texts"].any? { |text_card| text_card["title"] }
  end

  test "invalid parameters fall back to defaults" do
    get root_path(seed: "hello", likes: "lots", reviews: "-4", locale: "xx")
    assert_response :success
  end

  test "credits page lists the media library" do
    get credits_path
    assert_response :success
    assert_select ".credit-list li", minimum: 1
  end
end
