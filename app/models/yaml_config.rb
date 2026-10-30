module YamlConfig
  module_function

  def load(relative_path, fallback: nil)
    path = Rails.root.join(relative_path)
    return fallback if fallback && !File.exist?(path)

    YAML.load_file(path, aliases: true)
  end
end
