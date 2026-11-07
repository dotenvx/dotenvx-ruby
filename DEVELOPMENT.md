# Development

`dotenvx` is a mixed Ruby/Rust package. Magnus exposes the private
`dotenvx-ll` shared loader to Ruby, and `rb-sys` compiles the extension into
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

The shared loader owns the published `dotenvx-primitives` dependency. Update
it in Forge when the consumers should embed a newer primitives release.

## Publishing

Tags matching `v*` run the full test matrix, build five platform variants of
the existing `dotenvx` gem, and publish all of them to RubyGems. No additional
gem is published.

Before the first automated release, add a trusted publisher for the `dotenvx`
and `dotenvx-rails` gems on RubyGems.org with:

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

## Shared loader checkout

The native extension currently depends on private `dotenvx-ll` through a local
Cargo path. Keep this checkout beside `forge/`, which contains `dotenvx-ll/`.
It embeds published primitives 4.x through that loader, instead of depending on
primitives directly. Rebuild the extension after changing the loader.

These are local development paths, not a finished release-distribution setup.
Standalone CI/source-package builds need private access to the loader source
before publishing. Do not publish `dotenvx-ll` publicly; compiled platform gems
and wheels can embed it without distributing its Rust source.
