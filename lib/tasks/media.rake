namespace :media do
  desc "Download and normalise trailer footage"
  task clips: :environment do
    MediaLibraryBuilder::ClipCollector.new.collect
  end

  desc "Download and normalise trailer music and sound effects"
  task audio: :environment do
    MediaLibraryBuilder::AudioCollector.new.collect
  end

  desc "Download the trailer fonts as TTF files for the ffmpeg exporter"
  task fonts: :environment do
    MediaLibraryBuilder::FontDownloader.new.download_all
  end

  desc "Build the whole trailer media library"
  task fetch: %i[clips audio fonts]
end
