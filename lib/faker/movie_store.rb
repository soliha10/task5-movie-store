require "faker"

module Faker
  class MovieStore < Base
    TOKEN = /#\{([A-Za-z_][\w.]*)\}/
    MAX_DEPTH = 6

    class << self
      def genre_name(genre)
        translate("faker.movie_store.genres.#{genre}")
      end

      def person
        expand(fetch("movie_store.person"))
      end

      def stage_name
        expand(fetch("movie_store.stage_name"))
      end

      def character
        expand(fetch("movie_store.character"))
      end

      def title(genre:)
        scopes = ["title.by_genre.#{genre}", "title"]
        expand(pick("templates", scopes), scopes: scopes)
      end

      def plot(genre:, context:)
        scope = "plot.by_genre.#{genre}"
        [pick("setup", [scope]), pick("twist", [scope])].map { |s| expand(s, context: context) }.join(" ")
      end

      def trailer_hook(genre:)
        fetch("movie_store.trailer.hook.#{genre}")
      end

      def trailer_card(kind, context: {})
        expand(fetch("movie_store.trailer.#{kind}"), context: context, scopes: ["trailer"])
      end

      def review(sentiment:, context:)
        %w[open close].map { |part| expand(fetch("movie_store.review.#{sentiment}_#{part}"), context: context) }.join(" ")
      end

      def publication
        fetch("movie_store.review.publication")
      end

      def expand(template, context: {}, scopes: [], depth: 0)
        return template if depth > MAX_DEPTH

        template.to_s.gsub(TOKEN) do
          token = Regexp.last_match(1)
          if context.key?(token.to_sym)
            context[token.to_sym].to_s
          elsif token.include?(".")
            klass, method = token.split(".", 2)
            Faker.const_get(klass).public_send(method).to_s
          else
            expand(pick(token, scopes + [""]), context: context, scopes: scopes, depth: depth + 1)
          end
        end
      end

      private

      def pick(key, scopes)
        scopes.each do |scope|
          path = ["faker.movie_store", scope, key].reject(&:empty?).join(".")
          values = I18n.t(path, locale: Faker::Config.locale, default: nil)
          return sample(Array(values)) if values.present?
        end
        raise I18n::MissingTranslationData.new(Faker::Config.locale, "movie_store.#{key}")
      end
    end
  end
end
