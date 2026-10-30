require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Task5ruby
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks faker])

    config.i18n.load_path += Dir[Rails.root.join("config/locales/faker/*.yml")]

    config.generators.system_tests = nil
  end
end
