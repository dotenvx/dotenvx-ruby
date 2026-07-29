require "dotenvx/version"
require "dotenvx/dotenvx_native"

module Dotenvx
  class MissingKeys < RuntimeError
    attr_reader :keys

    def initialize(keys)
      @keys = keys
      super("Missing required configuration keys: #{keys.join(", ")}")
    end
  end

  class << self
    attr_accessor :instrumenter

    def load(*filenames, overwrite: false, ignore: true)
      env = parse(*filenames, overwrite: overwrite, ignore: ignore)
      update(env, overwrite: overwrite)
    end

    def load!(*filenames)
      load(*filenames, ignore: false)
    end

    def overwrite(*filenames)
      load(*filenames, overwrite: true)
    end
    alias overload overwrite

    def overwrite!(*filenames)
      load(*filenames, overwrite: true, ignore: false)
    end
    alias overload! overwrite!

    def parse(*filenames, overwrite: false, ignore: true)
      filenames = [".env"] if filenames.empty?
      filenames = filenames.flatten.reverse if overwrite

      process_env = ENV.to_h
      filenames.reduce({}) do |values, filename|
        path = File.expand_path(filename)
        begin
          source = File.binread(path).sub(/\A\xEF\xBB\xBF/, "").force_encoding(Encoding::UTF_8)
        rescue Errno::ENOENT, Errno::EISDIR
          raise unless ignore
          next values
        end

        parsed, = Native.parse_dotenv(
          source,
          process_env.to_a,
          overwrite == true,
          key_files(path)
        )
        parsed = parsed.to_h
        process_env.merge!(parsed)
        values.merge!(parsed)
        yield Environment.new(path, parsed) if block_given?
        values
      end
    end

    def update(env = {}, overwrite: false)
      changed = {}
      env.each do |key, value|
        key = key.to_s
        next if ENV.key?(key) && overwrite == false

        if ENV.key?(key) && overwrite == :warn
          warn "Warning: dotenvx not overwriting ENV[#{key.inspect}]"
          next
        end
        unless [true, false, :warn].include?(overwrite)
          raise ArgumentError, "Invalid value for overwrite: #{overwrite.inspect}"
        end

        ENV[key] = value.to_s
        changed[key] = value.to_s
      end
      changed
    end

    def require_keys(*keys)
      missing = keys.flatten.map(&:to_s) - ENV.keys
      raise MissingKeys, missing unless missing.empty?
    end

    private

    def key_files(path)
      basename = File.basename(path)
      candidates = ["#{path}.keys"]
      candidates << File.join(File.dirname(path), ".env.keys") unless basename == ".env"
      candidates.select { |candidate| File.file?(candidate) }
    end
  end

  class Environment < Hash
    attr_reader :filename

    def initialize(filename, values)
      @filename = filename
      super()
      update(values)
    end
  end
end
