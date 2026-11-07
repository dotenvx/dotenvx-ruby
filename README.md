[![dotenvx](https://dotenvx.com/better-banner.png)](https://dotenvx.com)

*a secure dotenv–from the creator of [`dotenv`](https://github.com/motdotla/dotenv).*

`dotenvx` loads plaintext and encrypted dotenv files through the shared `dotenvx-ll` Rust loader, backed by published
[`dotenvx-primitives`](https://crates.io/crates/dotenvx-primitives). The native extension is bundled in the gem; users do not need
Node.js, a dotenvx CLI, or a Rust toolchain.

## Install

```sh
gem install dotenvx
```

Or add it to a Gemfile:

```ruby
gem "dotenvx"
```

## Use

Load `.env` from the current directory:

```ruby
require "dotenvx/load"
```

Or load explicitly:

```ruby
require "dotenvx"

Dotenvx.load
Dotenvx.load(".env.local", ".env")
```

Existing environment variables win by default:

```ruby
Dotenvx.load(".env")
```

To replace existing values:

```ruby
Dotenvx.load(".env", overwrite: true)
Dotenvx.overwrite(".env")
```

Parse without changing `ENV`:

```ruby
values = Dotenvx.parse(".env")
```

Raise when a file is missing:

```ruby
Dotenvx.load!(".env")
```

Encrypted values are decrypted automatically when the matching private key is
available through the process environment, `<filename>.keys`, or `.env.keys`.

## Native platforms

Tagged releases publish variants of the same `dotenvx` gem for:

- Linux x86-64
- Linux ARM64
- macOS Intel
- macOS Apple Silicon
- Windows x64

RubyGems selects the correct variant during `gem install dotenvx`.

## Loading errors and policy

Loading errors are reported and loading continues by default. `strict: true`,
`load!`, or strictness in the current directory's Dotenvxfile stops loading and
raises before updating `ENV`. Dotenvxfile required/type/file rules are shared
with the CLI. Selected error codes can be ignored with `ignore: ["CODE"]`.

The shared loader returns redaction metadata without changing real application
values. Application-output redaction hooks are not installed by this adapter.

## Shared file selection

File discovery, directory expansion, conventions, and key-based filename
inference are resolved by `dotenvx-ll`. The CLI's file-selection and error-ignore
environment variables apply here too. Rails supplies its root and environment;
the shared loader chooses the Rails files and their order.

```ruby
Dotenvx.load(convention: "nextjs")
Dotenvx.load("app", key_files: "shared/.env.keys")
```
