require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Dotenvx do
  let(:private_key) { "a4547dcd9d3429615a3649bb79e87edb62ee6a74b007075e9141ae44f5fb412c" }
  let(:encrypted_world) do
    "encrypted:BE9Y7LKANx77X1pv1HnEoil93fPa5c9rpL/1ps48uaRT9zM8VR6mHx9yM+HktKdsPGIZELuZ7rr2mn1gScsmWitppAgE/1lVprNYBCqiYeaTcKXjDUXU5LfsEsflnAsDhT/kWG1l"
  end

  it "loads an explicit dotenv file without replacing existing values" do
    with_env_file("HELLO=World\nEXISTING=file\n") do |path|
      ENV["EXISTING"] = "environment"

      expect { described_class.load(path) }
        .to output("⟐ injected env (1) from #{path}\n").to_stderr
      expect(ENV["HELLO"]).to eq("World")
      expect(ENV["EXISTING"]).to eq("environment")
    end
  end

  it "supports dotenv-compatible overwrite aliases" do
    with_env_file("EXISTING=file\n") do |path|
      ENV["EXISTING"] = "environment"

      expect { described_class.overwrite(path) }
        .to output("⟐ injected env (1) from #{path}\n").to_stderr
      expect(ENV["EXISTING"]).to eq("file")
    end
  end

  it "parses without changing ENV" do
    with_env_file("PARSED=yes\n") do |path|
      expect { described_class.parse(path) }.not_to output.to_stderr
      expect(described_class.parse(path)).to eq("PARSED" => "yes")
      expect(ENV).not_to have_key("PARSED")
    end
  end

  it "counts unique injected keys across readable files" do
    Dir.mktmpdir do |directory|
      first = File.join(directory, ".env.local")
      second = File.join(directory, ".env")
      File.write(first, "FIRST=one\nSHARED=local\n")
      File.write(second, "SECOND=two\nSHARED=base\nEXISTING=file\n")
      ENV["EXISTING"] = "environment"

      expect { described_class.load(first, second) }
        .to output("⟐ injected env (3) from #{first}, #{second}\n").to_stderr
    end
  end

  it "decrypts with the process environment and no key file" do
    with_env_file("HELLO=#{encrypted_world}\n") do |path|
      ENV["DOTENV_PRIVATE_KEY"] = private_key
      expect(File.exist?("#{path}.keys")).to eq(false)
      expect(described_class.parse(path, strict: true)["HELLO"]).to eq("World")
    end
  end

  it "decrypts with the adjacent dotenvx key file" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".env")
      File.write(path, "HELLO=#{encrypted_world}\n")
      File.write("#{path}.keys", "DOTENV_PRIVATE_KEY=#{private_key}\n")

      expect { described_class.load(path) }
        .to output("⟐ injected env (1) from #{path}\n").to_stderr
      expect(ENV["HELLO"]).to eq("World")
    end
  end

  it "uses the conventional .env.keys file for named environment files" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".env.production")
      File.write(path, "HELLO=#{encrypted_world}\n")
      File.write(File.join(directory, ".env.keys"), "DOTENV_PRIVATE_KEY=#{private_key}\n")

      expect { described_class.load(path) }
        .to output("⟐ injected env (1) from #{path}\n").to_stderr
      expect(ENV["HELLO"]).to eq("World")
    end
  end

  it "warns and continues when a value cannot be decrypted" do
    with_env_file("HELLO=#{encrypted_world}\n") do |path|
      expect { described_class.load(path) }
        .to output(
          "☠ [DECRYPTION_FAILED] could not decrypt HELLO. fix: [https://github.com/dotenvx/dotenvx/issues/757]\n" \
          "⟐ injected env (1) from #{path}\n"
        ).to_stderr
      expect(ENV["HELLO"]).to eq(encrypted_world)
    end
  end

  it "supports strict decryption errors" do
    with_env_file("HELLO=#{encrypted_world}\n") do |path|
      expect { described_class.load(path, strict: true) }
        .to raise_error(Dotenvx::ParseError, /DECRYPTION_FAILED/)
    end
  end

  it "ignores selected error codes" do
    with_env_file("HELLO=#{encrypted_world}\n") do |path|
      expect { described_class.load(path, ignore: ["DECRYPTION_FAILED"]) }
        .to output("⟐ injected env (1) from #{path}\n").to_stderr
    end
  end

  it "warns about missing files by default and raises through load!" do
    missing = File.join(Dir.tmpdir, "dotenvx-does-not-exist")

    expect { expect(described_class.load(missing)).to eq({}) }
      .to output(/MISSING_ENV_FILE.*\n⟐ injected env \(0\)\n/).to_stderr
    expect { described_class.load!(missing) }.to raise_error(Errno::ENOENT)
  end


  it "infers filenames from environment key names in the shared loader" do
    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        ENV["DOTENV_PRIVATE_KEY_PRODUCTION"] = private_key
        File.write(".env.production", "HELLO=#{encrypted_world}\n")
        expect(Dotenvx.parse["HELLO"]).to eq("World")
      end
    end
  end

  it "accepts explicit key files without Ruby-side discovery" do
    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        File.write(".env", "HELLO=#{encrypted_world}\n")
        File.write("custom.keys", "DOTENV_PRIVATE_KEY=#{private_key}\n")
        expect(Dotenvx.parse(".env", key_files: "custom.keys")["HELLO"]).to eq("World")
      end
    end
  end

  context "with files in the working directory" do
    around do |example|
      Dir.mktmpdir do |directory|
        Dir.chdir(directory) { example.run }
      end
    end

    it "loads through the native language loader without a CLI" do
      File.write(".env", "LL_VALUE=World\n")
      expect { Dotenvx.load }.to output(/injected env/).to_stderr
      expect(ENV["LL_VALUE"]).to eq("World")
    end

    it "surfaces missing files without failing by default" do
      expect { expect(Dotenvx.load).to eq({}) }
        .to output(/MISSING_ENV_FILE.*missing file/).to_stderr
    end

    it "takes strictness from Dotenvxfile before reading files" do
      File.write("Dotenvxfile", "strict true\n")
      expect { Dotenvx.load }.to raise_error(Dotenvx::ParseError, /MISSING_ENV_FILE/)
    end

    it "reports policy errors and still loads values by default" do
      File.write(".env", "LL_PORT=invalid\nLL_VALUE=loaded\n")
      File.write("Dotenvxfile", 'env "LL_PORT", type: "port"')
      expect { Dotenvx.load }.to output(/INVALID_ENV/).to_stderr
      expect(ENV["LL_VALUE"]).to eq("loaded")
    end

    it "raises before changing ENV for explicit strictness" do
      File.write(".env", "LL_PORT=invalid\nLL_VALUE=not-loaded\n")
      File.write("Dotenvxfile", 'env "LL_PORT", type: "port"')
      expect { Dotenvx.load(strict: true) }.to raise_error(Dotenvx::ParseError, /INVALID_ENV/)
      expect(ENV).not_to have_key("LL_VALUE")
    end

    it "honors file-specific policy strictness" do
      File.write(".env", "LL_VALUE=not-loaded\n")
      File.write("Dotenvxfile", "file \".env\" do\n strict true\n env \"LL_REQUIRED\", required: true\nend")
      expect { Dotenvx.load }.to raise_error(Dotenvx::ParseError, /INVALID_ENV/)
      expect(ENV).not_to have_key("LL_VALUE")
    end

    it "ignores selected diagnostics even under policy strictness" do
      File.write(".env", "LL_VALUE=loaded\n")
      File.write("Dotenvxfile", "strict true\nenv \"LL_REQUIRED\", required: true")
      expect { Dotenvx.load(ignore: ["INVALID_ENV"]) }.to output(/injected env/).to_stderr
      expect(ENV["LL_VALUE"]).to eq("loaded")
    end

    it "uses run-style source ordering when overloading multiple files" do
      File.write("first.env", "LL_VALUE=first\n")
      File.write("second.env", "LL_VALUE=second\n")
      expect { Dotenvx.load("first.env", "second.env", overwrite: true) }.to output(/injected env/).to_stderr
      expect(ENV["LL_VALUE"]).to eq("second")
    end

    it "returns policy redaction metadata without redacting application values" do
      File.write(".env", "LL_SECRET=real-value\n")
      File.write("Dotenvxfile", 'env "LL_SECRET", redacted: true')
      result = JSON.parse(Dotenvx::Native.load_env(JSON.generate(
        sources: [{type: "file", value: ".env"}], cwd: Dir.pwd, process_env: {}
      )))
      expect(result.fetch("secrets")).to eq(["real-value"])
      expect(result.fetch("values")).to eq("LL_SECRET" => "real-value")
      expect(ENV).not_to have_key("LL_SECRET")
    end

    it "selects convention files in Rust and skips absent optional files" do
      File.write(".env.development.local", "LL_VALUE=first\n")
      File.write(".env", "LL_VALUE=base\n")
      expect(Dotenvx.parse(convention: "nextjs")["LL_VALUE"]).to eq("first")
    end

    it "uses environment-selected conventions and excludes local files in test" do
      ENV["DOTENV_CONVENTION"] = "nextjs"
      ENV["NODE_ENV"] = "test"
      File.write(".env.local", "LL_LOCAL=excluded\n")
      File.write(".env.test", "LL_VALUE=test\n")
      expect(Dotenvx.parse).to eq("LL_VALUE" => "test")
    end

    it "expands directories and finds neighboring key files in Rust" do
      FileUtils.mkdir_p("app")
      File.write("app/.env", "LL_VALUE=directory\n")
      expect(Dotenvx.parse("app")).to eq("LL_VALUE" => "directory")
    end

    it "supports Rails environments without duplicating the Rails file list" do
      File.write(".env.review.local", "LL_VALUE=review\n")
      File.write(".env", "LL_VALUE=base\n")
      expect(Dotenvx.parse(".", convention: "rails", environment: "review")["LL_VALUE"]).to eq("review")
    end

    it "uses file configuration from ENV unless filenames are supplied" do
      ENV["DOTENV_FILE"] = "custom.env"
      File.write("custom.env", "LL_VALUE=configured\n")
      File.write("explicit.env", "LL_VALUE=explicit\n")
      expect(Dotenvx.parse["LL_VALUE"]).to eq("configured")
      expect(Dotenvx.parse("explicit.env")["LL_VALUE"]).to eq("explicit")
    end

    it "honors ignored error codes from ENV in the shared loader" do
      ENV["DOTENV_IGNORE"] = "MISSING_ENV_FILE"
      expect(Dotenvx.parse("missing.env", strict: true)).to eq({})
    end

    it "reports invalid conventions through the shared diagnostics" do
      expect { Dotenvx.load(convention: "unknown") }
        .to raise_error(Dotenvx::ParseError, /INVALID_CONVENTION/)
    end
  end

  def with_env_file(contents)
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".env")
      File.write(path, contents)
      yield path
    end
  end
end
