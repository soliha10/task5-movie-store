module MediaLibraryBuilder
  PUBLIC_DIRECTORY = Rails.root.join("public/media")
  DOWNLOAD_DIRECTORY = Rails.root.join("tmp/media")
  MANIFEST_DIRECTORY = Rails.root.join("config/media")
  SOURCES_PATH = "config/media/sources.yml"

  module_function

  def sources
    @sources ||= YamlConfig.load(SOURCES_PATH)
  end

  def write_manifest(name, entries)
    path = MANIFEST_DIRECTORY.join("#{name}.yml")
    File.write(path, entries.to_yaml)
    puts "#{entries.size} entries -> #{path.relative_path_from(Rails.root)}"
  end
end
