Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "movies#index"
  get "movies/batch" => "movies#batch", as: :movies_batch
  get "movies/:index/trailer" => "trailers#show", as: :movie_trailer, constraints: { index: /\d+/ }
  get "export" => "exports#show", as: :export
  get "credits" => "pages#credits", as: :credits
end
