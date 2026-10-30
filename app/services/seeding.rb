require "zlib"
require "digest"

module Seeding
  BIT_MASK_64 = (1 << 64) - 1
  PAGE_SEED_MULTIPLIER = 6_364_136_223_846_793_005
  SPLITMIX_INCREMENT = 0x9E3779B97F4A7C15
  SPLITMIX_MULTIPLIER_1 = 0xBF58476D1CE4E5B9
  SPLITMIX_MULTIPLIER_2 = 0x94D049BB133111EB
  NUMERIC_SEED = /\A\d+\z/

  module_function

  def parse(raw_seed)
    text = raw_seed.to_s.strip
    return 0 if text.empty?
    return text.to_i & BIT_MASK_64 if text.match?(NUMERIC_SEED)

    Digest::SHA256.digest(text).unpack1("Q>")
  end

  def page_seed(seed, page_number)
    (seed * PAGE_SEED_MULTIPLIER + page_number) & BIT_MASK_64
  end

  def record_seed(page_seed, record_position, region_salt, stream_name)
    mix(page_seed ^ mix(record_position) ^ mix(region_salt) ^ Zlib.crc32(stream_name))
  end

  def salt(text)
    Zlib.crc32(text.to_s)
  end

  def mix(value)
    value = (value + SPLITMIX_INCREMENT) & BIT_MASK_64
    value = ((value ^ (value >> 30)) * SPLITMIX_MULTIPLIER_1) & BIT_MASK_64
    value = ((value ^ (value >> 27)) * SPLITMIX_MULTIPLIER_2) & BIT_MASK_64
    value ^ (value >> 31)
  end
end
