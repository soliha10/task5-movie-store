class TrailerBatchRenderer
  WORKER_COUNT = ENV.fetch("EXPORT_WORKERS", 3).to_i

  def initialize(movies)
    @movies = movies
  end

  def render
    queue = Queue.new
    @movies.each { |movie| queue << movie }
    rendered_files = {}
    workers = Array.new(WORKER_COUNT) { Thread.new { render_from_queue(queue, rendered_files) } }
    workers.each(&:join)
    rendered_files
  end

  private

  def render_from_queue(queue, rendered_files)
    until queue.empty?
      movie = queue.pop(true)
      rendered_files[movie.index] = TrailerRenderer.new(movie.trailer).render
    end
  rescue ThreadError
    nil
  end
end
