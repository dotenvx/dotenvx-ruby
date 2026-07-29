require_relative 'lib/dotenvx/version'

Gem::Specification.new "dotenvx" do |spec|
  spec.name          = "dotenvx"
  spec.version       = Dotenvx::VERSION
  spec.authors       = ["motdotla"]
  spec.email         = ["mot@mot.la"]

  spec.summary       = %q{[dotenvx.com] a better dotenv–from the creator of `dotenv`}
  spec.description   = %q{[dotenvx.com] a better dotenv–from the creator of `dotenv`}
  spec.homepage      = "https://github.com/dotenvx/dotenvx-ruby"
  spec.license       = "BSD-3-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")
  spec.required_rubygems_version = Gem::Requirement.new(">= 3.3.11")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dotenvx/dotenvx-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/dotenvx/dotenvx-ruby"

  spec.files = Dir[
    "Cargo.lock",
    "Cargo.toml",
    "CHANGELOG.md",
    "LICENSE",
    "README.md",
    "ext/dotenvx/**/*",
    "lib/dotenvx.rb",
    "lib/dotenvx/**/*"
  ].reject do |file|
    File.directory?(file) || file.match?(/dotenvx_native\.(bundle|dll|so)\z/)
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/dotenvx/extconf.rb"]

  spec.add_dependency "rb_sys", "~> 0.9"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.3"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "byebug"
end
