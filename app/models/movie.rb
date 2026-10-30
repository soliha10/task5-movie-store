# One generated movie (or series). Plain value object — nothing is persisted.
Movie = Data.define(
  :index, :kind, :genre, :genre_name, :title, :year, :cast, :director, :runtime,
  :seasons, :episodes, :age_rating, :badges, :plot, :score, :likes, :reviews, :trailer
) do
  def series? = kind == :series
end

Review = Data.define(:author, :publication, :text, :sentiment)
