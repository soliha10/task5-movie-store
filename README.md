# ReelForge — fake movie store with generated trailers

A Ruby on Rails single-page app that shows an endless catalog of fake but realistic movies and series. Every record has its own 7–10 second trailer: real footage, a colour grade, transitions, animated title typography, music and sound effects.

Everything is generated in memory from **seed + region + record index**. Nothing is stored, and the same parameters always give the same titles, casts, reviews and trailers.

## Features

- **Toolbar** in one row: language/region, a 64-bit seed with a random button, average likes (slider, 0–10), average reviews (0–10). Data updates as you type.
- **Table view** with pagination and no upper limit. Clicking a row expands it to show the trailer poster (a freeze frame with the title), a play button, cast, director, plot, badges, likes and reviews.
- **Gallery view** with infinite scroll (lazy Turbo Frames). Clicking a card opens the details and trailer in a modal.
- **Export**: a ZIP of the current table page's trailers rendered to MP4 by ffmpeg, one file per movie named after its title.
- **Series** with seasons and episodes, mixed into the catalog.
- **Regions**: English (USA), German (Germany), Ukrainian (Ukraine).

## How generation works

| Piece | Where |
| --- | --- |
| Seed arithmetic | `app/services/seeding.rb`. The batch seed is a multiply-add of the user seed and the page number (`seed * 6364136223846793005 + page`). Each record mixes the batch seed, its position, the region and a stream name with SplitMix64. |
| Independent streams | `core` (title, cast, genre…), `trailer`, `likes`, `reviews`, and `review:k` per review. Changing likes changes only likes. Raising the review count adds reviews and keeps the existing ones. |
| Fractional averages | `floor(v)` plus one more with probability `frac(v)`. For example, 0.5 gives 0 or 1 at 50/50, and 10 gives exactly 10. |
| Fake data | [Faker](https://github.com/faker-ruby/faker), extended with `Faker::MovieStore` (`lib/faker/movie_store.rb`). It uses Faker's API (`fetch`, `translate`, `sample`, `Faker::Name`, `Faker::Address`) with the seeded `Faker::Config.random`. |
| Trailer spec | `app/services/trailer_spec.rb` decides footage, in-points, speed, zoom/pan, grade, transitions, text cards, fonts, animation styles, music and SFX timing. The decisions come from the genre catalog. |
| Browser player | `app/javascript/trailer/*.js`. PixiJS (WebGL) with pixi-filters for grading, grain, vignette, bloom, glitch, zoom and motion blur. GSAP drives the timeline and the 15 typography animations. Web Audio handles the mix. Visual details use a PRNG seeded from the spec. |
| MP4 export | `app/services/trailer_renderer.rb` turns the same spec into an ffmpeg `filter_complex`. |

All generation runs on the server. The browser only receives a page of HTML plus a JSON trailer spec, and plays it.

## Region data, no hard-coded words

Every word a user sees comes from data files:

- `config/locales/faker/movie_store.<locale>.yml`: genres, name patterns, title templates and word pools per genre, plots, trailer cards ("THIS FALL", hooks, studios), and review sentences.
- `config/regions/<code>.yml`: display name, Faker locale, age-rating system (MPAA / FSK / UA) and UI labels.

To add a region, add these two files. The language dropdown is built from `config/regions`. The title, plot and review datasets were written with an AI model, which generated the data rather than code.

## Trailer media

`bin/rails media:fetch` builds the footage and audio library from free-license [Mixkit](https://mixkit.co/license/) footage, music and sound effects. For each genre it searches several tags, filters out clips that don't fit the mood, and normalises the files with ffmpeg:

- 640×360 clips of about 5 seconds
- music trimmed to the loudest 11 seconds, loudness-normalised
- short sound effects

Manifests are written to `config/media/*.yml`. `bin/rails media:fonts` downloads the display fonts as TTF files for the exporter. Every font covers Latin and Cyrillic.

There are about 400 clips, 12 genres × 5 structures, 23 grade presets, 9 transitions, 15 text animations, 19 fonts, 84 music beds and 48 sound effects. The combinations run into the millions.

## Running locally

Requires Ruby (see `.ruby-version`) and ffmpeg.

```sh
bundle install
bin/rails media:fetch media:fonts   # only if public/media is empty
bin/rails server
bin/rails test
```

## Deploying

The included `Dockerfile` installs ffmpeg. `render.yaml` deploys the app as a free Render web service and generates `SECRET_KEY_BASE`. Any Docker host works.

## Libraries

Rails 8, Turbo, Stimulus, importmap, Faker, rubyzip, Bootstrap 5, Bootstrap Icons, PixiJS 8.9.2, pixi-filters 6.1.0, GSAP 3.13.0 (vendored in `vendor/javascript`), ffmpeg, Google Fonts.
