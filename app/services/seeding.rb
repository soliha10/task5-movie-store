require "zlib"
require "digest"

# Deterministic seed arithmetic. Everything is plain 64-bit integer math, so the
# same user seed produces the same data on any machine, any day.
module Seeding
  MASK = (1 << 64) - 1
  MULTIPLIER = 6_364_136_223_846_793_005 # Knuth's MMIX LCG multiplier

  module_function

  # "123" -> 123; anything non-numeric is hashed so it is still reproducible.
  def parse(value)
    str = value.to_s.strip
    return 0 if str.empty?
    return str.to_i & MASK if str.match?(/\A\d+\z/)

    Digest::SHA256.digest(str).unpack1("Q>")
  end

  # The seed of one page/batch: a multiply-add of the user seed and the page number.
  def page_seed(seed, page)
    (seed * MULTIPLIER + page) & MASK
  end

  # Seed of one record, for one independent stream ("core", "likes", "review:3"...).
  # Streams are independent, so changing likes never touches titles and so on.
  def record_seed(page_seed, position, salt, stream)
    mix(page_seed ^ mix(position) ^ mix(salt) ^ Zlib.crc32(stream))
  end

  def salt(text)
    Zlib.crc32(text.to_s)
  end

  # SplitMix64 finalizer.
  def mix(x)
    x = (x + 0x9E3779B97F4A7C15) & MASK
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & MASK
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & MASK
    x ^ (x >> 31)
  end
end
