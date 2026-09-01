require "dotenvx/version"
require "dotenvx/dotenvx_native"
require "json"
require "pathname"

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
      env, injected_keys, loaded_paths = parse_files(
        *filenames,
        overwrite: overwrite,
        ignore: ignore
      )
      changed = update(env, overwrite: overwrite)
      log_injected(injected_keys, loaded_paths)
      changed
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
      parse_files(*filenames, overwrite: overwrite, ignore: ignore).first
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

    def parse_files(*filenames, overwrite: false, ignore: true)
      filenames = [".env"] if filenames.empty?
      filenames = filenames.flatten.reverse if overwrite

      process_env = ENV.to_h
      injected_keys = {}
      loaded_paths = []
      values = filenames.reduce({}) do |accumulator, filename|
        path = File.expand_path(filename)
        begin
          source = File.binread(path).sub(/\A\xEF\xBB\xBF/, "").force_encoding(Encoding::UTF_8)
        rescue Errno::ENOENT, Errno::EISDIR
          raise unless ignore
          next accumulator
        end

        parsed, injected = Native.parse_dotenv(JSON.generate(
          source: source,
          process_env: process_env,
          overwrite: overwrite == true,
          key_files: key_files(path)
        ))
        parsed = parsed.to_h
        injected.each { |key, _value| injected_keys[key] = true }
        loaded_paths << path
        process_env.merge!(parsed)
        accumulator.merge!(parsed)
        yield Environment.new(path, parsed) if block_given?
        accumulator
      end
      [values, injected_keys.keys, loaded_paths]
    end

    def log_injected(injected_keys, loaded_paths)
      message = "⟐ injected env (#{injected_keys.length})"
      unless loaded_paths.empty?
        paths = loaded_paths.map { |path| readable_path(path) }
        message = "#{message} from #{paths.join(", ")}"
      end
      warn message
    end

    def readable_path(path)
      pathname = Pathname.new(path)
      relative = pathname.relative_path_from(Pathname.pwd).to_s
      relative.start_with?("../") ? pathname.to_s : relative
    rescue ArgumentError
      pathname.to_s
    end

    def key_files(path)
      candidates = ["#{path}.keys", File.join(File.dirname(path), ".env.keys")]
      candidates.select { |candidate| File.file?(candidate) }
        .uniq
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
