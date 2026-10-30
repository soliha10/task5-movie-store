require "faker"

module Faker
  class MovieStore < Base
    TOKEN = /#\{([A-Za-z_][\w.]*)\}/
    MAX_EXPANSION_DEPTH = 6
    ROOT_KEY = "faker.movie_store"

    class << self
      def genre_name(genre)
        translate("#{ROOT_KEY}.genres.#{genre}")
      end

      def person
        expand(fetch_pool("person"))
      end

      def stage_name
        expand(fetch_pool("stage_name"))
      end

      def character
        expand(fetch_pool("character"))
      end

      def title(genre:)
        scopes = ["title.by_genre.#{genre}", "title"]
        expand(sample_from_scopes("templates", scopes), scopes: scopes)
      end

      def plot(genre:, context:)
        scopes = ["plot.by_genre.#{genre}"]
        sentences = [sample_from_scopes("setup", scopes), sample_from_scopes("twist", scopes)]
        sentences.map { |sentence| expand(sentence, context: context) }.join(" ")
      end

      def trailer_hook(genre:)
        fetch_pool("trailer.hook.#{genre}")
      end

      def trailer_card(kind, context: {})
        expand(fetch_pool("trailer.#{kind}"), context: context, scopes: ["trailer"])
      end

      def review(sentiment:, context:)
        %w[open close].map { |part| expand(fetch_pool("review.#{sentiment}_#{part}"), context: context) }.join(" ")
      end

      def publication
        fetch_pool("review.publication")
      end

      def expand(template, context: {}, scopes: [], depth: 0)
        return template if depth > MAX_EXPANSION_DEPTH

        template.to_s.gsub(TOKEN) { resolve_token(Regexp.last_match(1), context, scopes, depth) }
      end

      private

      def resolve_token(token, context, scopes, depth)
        return context[token.to_sym].to_s if context.key?(token.to_sym)
        return faker_call(token) if token.include?(".")

        expand(sample_from_scopes(token, scopes + [""]), context: context, scopes: scopes, depth: depth + 1)
      end

      def faker_call(token)
        class_name, method_name = token.split(".", 2)
        Faker.const_get(class_name).public_send(method_name).to_s
      end

      def fetch_pool(key)
        fetch("movie_store.#{key}")
      end

      def sample_from_scopes(key, scopes)
        scopes.each do |scope|
          values = I18n.t([ROOT_KEY, scope, key].reject(&:empty?).join("."), locale: Faker::Config.locale, default: nil)
          return sample(Array(values)) if values.present?
        end
        raise I18n::MissingTranslationData.new(Faker::Config.locale, "movie_store.#{key}")
      end
    end
  end
end
