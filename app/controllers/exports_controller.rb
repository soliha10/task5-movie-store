# ZIP with the rendered trailers of the current table page, one MP4 per movie named after its title.
class ExportsController < ApplicationController
  include GenerationParams

  WORKERS = ENV.fetch("EXPORT_WORKERS", 3).to_i

  def show
    movies = generator.page(state.page)
    queue = Queue.new
    movies.each { |m| queue << m }
    files = {}
    Array.new(WORKERS) do
      Thread.new do
        while (movie = queue.pop(true) rescue nil)
          files[movie.index] = TrailerRenderer.new(movie.trailer).render
        end
      end
    end.each(&:join)

    names = Hash.new(0)
    zip = Zip::OutputStream.write_buffer do |out|
      movies.each do |movie|
        name = file_name(movie.title)
        names[name] += 1
        name = "#{name} (#{names[name]})" if names[name] > 1
        out.put_next_entry("#{name}.mp4")
        out.write(File.binread(files[movie.index]))
      end
    end
    send_data zip.string, type: "application/zip",
              filename: "trailers-#{state.region.code}-#{state.seed}-page#{state.page}.zip"
  end

  private

  def file_name(title)
    title.gsub(%r{[/\\:*?"<>|\x00-\x1f]}, " ").squish.presence || "trailer"
  end
end
