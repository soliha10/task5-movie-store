module MoviesHelper
  PAGE_LINK_SPAN = 2
  CARD_CAST_LIMIT = 3
  VIEW_ICONS = { "table" => "bi-table", "gallery" => "bi-grid-3x3-gap-fill" }.freeze

  def region_label(*path)
    state.region.label(*path)
  end

  def cast_names(movie, limit: nil)
    (limit ? movie.cast.first(limit) : movie.cast).join(", ")
  end

  def card_cast_names(movie)
    cast_names(movie, limit: CARD_CAST_LIMIT)
  end

  def runtime_summary(movie)
    runtime = "#{movie.runtime} #{region_label(:minutes)}"
    return runtime unless movie.series?

    "#{movie.seasons} #{region_label(:seasons)} · #{movie.episodes} #{region_label(:episodes)} · #{runtime}"
  end

  def movies_page_path(page_number)
    root_path(state.query(page: page_number))
  end

  def nearby_page_numbers
    ([state.page - PAGE_LINK_SPAN, GenerationState::FIRST_PAGE].max..state.page + PAGE_LINK_SPAN)
  end

  def page_item(page_number, text: page_number, title: nil, disabled: false)
    item_classes = class_names("page-item", active: page_number == state.page && text == page_number, disabled: disabled)
    tag.li(class: item_classes) { link_to(text, movies_page_path(page_number), class: "page-link", title: title) }
  end

  def next_batch_path(page_number)
    movies_batch_path(state.query(page: page_number + 1))
  end

  def view_toggle(view)
    input_id = "view-#{view}"
    safe_join([
      radio_button_tag(:view, view, state.view == view, id: input_id, class: "btn-check", data: { action: "change->toolbar#submit" }),
      label_tag(input_id, tag.i(class: "bi #{VIEW_ICONS.fetch(view)}"), class: "btn btn-outline-primary", title: view.capitalize)
    ])
  end
end
