require "spec_helper"
require "tmpdir"

RSpec.describe Dotenvx do
  let(:private_key) { "a4547dcd9d3429615a3649bb79e87edb62ee6a74b007075e9141ae44f5fb412c" }
  let(:encrypted_world) do
    "encrypted:BE9Y7LKANx77X1pv1HnEoil93fPa5c9rpL/1ps48uaRT9zM8VR6mHx9yM+HktKdsPGIZELuZ7rr2mn1gScsmWitppAgE/1lVprNYBCqiYeaTcKXjDUXU5LfsEsflnAsDhT/kWG1l"
  end

  it "loads an explicit dotenv file without replacing existing values" do
    with_env_file("HELLO=World\nEXISTING=file\n") do |path|
      ENV["EXISTING"] = "environment"

      expect(described_class.load(path)).to eq("HELLO" => "World")
      expect(ENV["HELLO"]).to eq("World")
      expect(ENV["EXISTING"]).to eq("environment")
    end
  end

  it "supports dotenv-compatible overwrite aliases" do
    with_env_file("EXISTING=file\n") do |path|
      ENV["EXISTING"] = "environment"

      expect(described_class.overwrite(path)).to eq("EXISTING" => "file")
      expect(ENV["EXISTING"]).to eq("file")
    end
  end

  it "parses without changing ENV" do
    with_env_file("PARSED=yes\n") do |path|
      expect(described_class.parse(path)).to eq("PARSED" => "yes")
      expect(ENV).not_to have_key("PARSED")
    end
  end

  it "decrypts with the adjacent dotenvx key file" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".env")
      File.write(path, "HELLO=#{encrypted_world}\n")
      File.write("#{path}.keys", "DOTENV_PRIVATE_KEY=#{private_key}\n")

      expect(described_class.load(path)).to eq("HELLO" => "World")
      expect(ENV["HELLO"]).to eq("World")
    end
  end

  it "ignores missing files by default and raises through load!" do
    missing = File.join(Dir.tmpdir, "dotenvx-does-not-exist")

    expect(described_class.load(missing)).to eq({})
    expect { described_class.load!(missing) }.to raise_error(Errno::ENOENT)
  end

  it "requires configuration keys" do
    expect { described_class.require_keys("MISSING") }
      .to raise_error(Dotenvx::MissingKeys, /MISSING/)
  end

  def with_env_file(contents)
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".env")
      File.write(path, contents)
      yield path
    end
  end
end
