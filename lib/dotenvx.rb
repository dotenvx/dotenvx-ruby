require "dotenvx/version"
require "dotenvx/dotenvx_native"
require "json"
require "pathname"

module Dotenvx
  class ParseError < RuntimeError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  class << self
    attr_accessor :instrumenter

    def load(*filenames, overwrite: false, ignore: [], strict: false, convention: nil, environment: nil, key_files: nil)
      env, injected_keys, loaded_paths = parse_files(
        *filenames,
        overwrite: overwrite,
        ignore: ignore,
        strict: strict,
        convention: convention,
        environment: environment,
        key_files: key_files
      )
      changed = update(env, overwrite: overwrite)
      log_injected(injected_keys, loaded_paths)
      changed
    end

    def load!(*filenames)
      load(*filenames, ignore: false, strict: true)
    end

    def overwrite(*filenames)
      load(*filenames, overwrite: true)
    end
    alias overload overwrite

    def overwrite!(*filenames)
      load(*filenames, overwrite: true, ignore: false, strict: true)
    end
    alias overload! overwrite!

    def parse(*filenames, overwrite: false, ignore: [], strict: false, convention: nil, environment: nil, key_files: nil)
      parse_files(
        *filenames,
        overwrite: overwrite,
        ignore: ignore,
        strict: strict,
        convention: convention,
        environment: environment,
        key_files: key_files
      ).first
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

    private

    def parse_files(*filenames, overwrite: false, ignore: [], strict: false, convention: nil, environment: nil, key_files: nil)
      filenames = filenames.flatten
      ignored_codes = Array(ignore).grep(String)
      ignored_codes << "MISSING_ENV_FILE" if ignore == true
      result = JSON.parse(Native.load_env(JSON.generate(
        sources: filenames.map { |filename| { type: "file", value: filename.to_s } },
        cwd: Dir.pwd,
        convention: convention,
        environment_name: environment,
        key_files: key_files.nil? ? nil : Array(key_files).map(&:to_s),
        process_env: ENV.to_h,
        overload: overwrite == true,
        strict: strict,
        ignore: ignored_codes,
        adjacent_keys: true
      )))
      result.fetch("diagnostics").each do |error|
        if error.fetch("strict")
          if error["code"] == "MISSING_ENV_FILE" && ignore == false
            raise Errno::ENOENT, error["path"]
          end
          raise ParseError.new(error.fetch("code"), error.fetch("message"))
        end
        warn "☠ #{error.fetch("message")}"
      end
      [result.fetch("values"), result.fetch("injected").keys,
        result.fetch("files").map { |file| file.fetch("filepath") }]
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
