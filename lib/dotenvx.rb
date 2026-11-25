require "dotenvx/version"
require "dotenvx/dotenvx_native"
require "json"
require "dotenvx/output"

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

    def load(*filenames, overwrite: false, ignore: [], strict: false, convention: nil, environment: nil, key_files: nil, resolve_references: false)
      env, summary, secrets = parse_files(
        *filenames,
        overwrite: overwrite,
        ignore: ignore,
        strict: strict,
        convention: convention,
        environment: environment,
        key_files: key_files,
        resolve_references: resolve_references
      )
      changed = update(env, overwrite: overwrite)
      Output.install(secrets)
      warn summary if summary
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

    def parse(*filenames, overwrite: false, ignore: [], strict: false, convention: nil, environment: nil, key_files: nil, resolve_references: false)
      parse_files(
        *filenames,
        overwrite: overwrite,
        ignore: ignore,
        strict: strict,
        convention: convention,
        environment: environment,
        key_files: key_files,
        resolve_references: resolve_references
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

    def parse_files(*filenames, overwrite: false, ignore: [], strict: false, convention: nil, environment: nil, key_files: nil, resolve_references: false)
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
        resolve_references: resolve_references,
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
      [result.fetch("values"), result.fetch("inject_summary"), result.fetch("secrets")]
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
