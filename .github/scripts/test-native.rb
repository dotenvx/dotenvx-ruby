require "dotenvx" unless defined?(Dotenvx::Native)
require "json"
require "tmpdir"

def assert_equal(expected, actual, label)
  abort "#{label}: expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
end

assert_equal(ARGV.fetch(0), Dotenvx::VERSION, "gem version") unless ARGV.empty?

# Exercise embedded and heap-backed arrays/strings using the SAME binary on
# every supported Ruby version. Their internal layouts are not interchangeable.
[1, 2, 3, 4, 8].each do |count|
  secrets = Array.new(count) { |index| "secret-#{index}" }
  filter = Dotenvx::Native::OutputRedactor.new
  filter.add(secrets)
  actual = secrets.map do |secret|
    filter.write(secret[0, 4]) + filter.write(secret[4..]) + filter.write(" ")
  end.join + filter.finish
  assert_equal("[REDACTED] " * count, actual, "redaction with #{count} secrets")
end

["", "short", "long string " * 20, "hello\x00world".b, "héllo 🔑"].each do |text|
  filter = Dotenvx::Native::OutputRedactor.new
  actual = filter.write(text.freeze) + filter.finish
  assert_equal(text.b, actual.b, "unmasked bytes")
end

filter = Dotenvx::Native::OutputRedactor.new
filter.add(["🔑secret"])
bytes = "prefix 🔑secret suffix".b.bytes
actual = bytes.map { |byte| filter.write(byte.chr) }.join + filter.finish
assert_equal("prefix [REDACTED] suffix", actual, "split UTF-8 secret")

Dir.mktmpdir("dotenvx-native-smoke-") do |directory|
  Dir.chdir(directory) do
    # A short JSON input exercises the loader's embedded-string conversion too.
    result = JSON.parse(Dotenvx::Native.load_env("{}"))
    assert_equal({}, result.fetch("values"), "empty loader result")
  end
end

puts "Native gem checks passed on Ruby #{RUBY_VERSION}"
