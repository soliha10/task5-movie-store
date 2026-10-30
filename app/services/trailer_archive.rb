class TrailerArchive
  FORBIDDEN_FILE_NAME_CHARACTERS = %r{[/\\:*?"<>|\x00-\x1f]}
  FALLBACK_FILE_NAME = "trailer"

  def initialize(movies)
    @movies = movies
  end

  def to_zip
    rendered_files = TrailerBatchRenderer.new(@movies).render
    file_names = unique_file_names
    Zip::OutputStream.write_buffer do |zip|
      @movies.each do |movie|
        zip.put_next_entry("#{file_names.fetch(movie.index)}.mp4")
        zip.write(File.binread(rendered_files.fetch(movie.index)))
      end
    end.string
  end

  private

  def unique_file_names
    name_counts = Hash.new(0)
    @movies.to_h do |movie|
      name = safe_file_name(movie.title)
      name_counts[name] += 1
      [movie.index, name_counts[name] > 1 ? "#{name} (#{name_counts[name]})" : name]
    end
  end

  def safe_file_name(title)
    title.gsub(FORBIDDEN_FILE_NAME_CHARACTERS, " ").squish.presence || FALLBACK_FILE_NAME
  end
end
