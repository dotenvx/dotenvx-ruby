# Development

`dotenvx` is a mixed Ruby/Rust package. Magnus exposes the published
`dotenvx-primitives` crate to Ruby, and `rb-sys` compiles the extension into
`lib/dotenvx`.

## Setup

```sh
bundle install
bundle exec rake compile
bundle exec rspec
```

Validate Rust:

```sh
cargo fmt --check
cargo clippy --workspace --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
cargo audit
```

Build and inspect the native gem for the current platform:

```sh
bundle exec rake package:native
gem specification pkg/dotenvx-*.gem
```

## Versions

The Ruby gem and native crate versions must match. Change both:

```text
lib/dotenvx/version.rb
ext/dotenvx/Cargo.toml
```

Then refresh dependency locks:

```sh
cargo check
bundle install
```

The `dotenvx-primitives` dependency is versioned independently. Update it in
`ext/dotenvx/Cargo.toml` only when the gem should embed a newer primitives
release.

## Publishing

Tags matching `v*` run the full test matrix, build five platform variants of
the existing `dotenvx` gem, and publish all of them to RubyGems. No additional
gem is published.

Before the first automated release, add a trusted publisher for the `dotenvx`
gem on RubyGems.org with:

- repository owner: `dotenvx`
- repository name: `dotenvx-ruby`
- workflow filename: `ci.yml`
- environment: `release`

The workflow uses a short-lived RubyGems credential through GitHub OIDC, so no
long-lived API-key secret is needed.

After updating both version sources and the changelog:

```sh
git tag v4.0.0
git push origin v4.0.0
```

The tag must match `Dotenvx::VERSION`. CI verifies this before packaging.
