require_relative 'lib/dotenvx/version'

Gem::Specification.new "dotenvx-rails" do |spec|
  spec.name          = "dotenvx-rails"
  spec.version       = Dotenvx::VERSION
  spec.authors       = ["motdotla"]
  spec.email         = ["mot@mot.la"]

  spec.summary       = %q{[dotenvx.com] a better dotenv–from the creator of `dotenv`}
  spec.description   = %q{[dotenvx.com] a better dotenv–from the creator of `dotenv`}
  spec.homepage      = "https://github.com/dotenvx/dotenvx-ruby"
  spec.license       = "BSD-3-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dotenvx/dotenvx-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/dotenvx/dotenvx-ruby"

  spec.files = [
    "CHANGELOG.md",
    "LICENSE",
    "README.md",
    "lib/dotenvx-rails.rb",
    "lib/dotenvx/rails.rb"
  ]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

	spec.add_dependency "dotenvx", Dotenvx::VERSION
	spec.add_dependency "railties", ">= 5.0"

	spec.add_development_dependency "spring"
	spec.add_development_dependency "byebug"
end
