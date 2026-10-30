# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "pixi.js", to: "pixi.js" # @8.9.2 dist/pixi.min.mjs
pin "pixi-filters", to: "pixi-filters.js" # @6.1.0 dist/pixi-filters.mjs
pin "gsap", to: "gsap.js" # @3.13.0
pin_all_from "app/javascript/trailer", under: "trailer"
