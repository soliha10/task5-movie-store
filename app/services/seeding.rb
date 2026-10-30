require "zlib"
require "digest"

module Seeding
  MASK = (1 << 64) - 1
  MULTIPLIER = 6_364_136_223_846_793_005

  module_function

  def parse(value)
    str = value.to_s.strip
    return 0 if str.empty?
    return str.to_i & MASK if str.match?(/\A\d+\z/)

    Digest::SHA256.digest(str).unpack1("Q>")
  end

  def page_seed(seed, page)
    (seed * MULTIPLIER + page) & MASK
  end

  def record_seed(page_seed, position, salt, stream)
    mix(page_seed ^ mix(position) ^ mix(salt) ^ Zlib.crc32(stream))
  end

  def salt(text)
    Zlib.crc32(text.to_s)
  end

  def mix(x)
    x = (x + 0x9E3779B97F4A7C15) & MASK
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & MASK
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & MASK
    x ^ (x >> 31)
  end
end
