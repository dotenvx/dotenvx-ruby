require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "shared language loader" do
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
