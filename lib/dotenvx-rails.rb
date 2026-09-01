require "dotenvx"
require "dotenvx/rails"

# Rails applications commonly read ENV immediately after Bundler.require,
# before Rails runs its before_configuration hooks. Load once when Bundler
# requires this gem so those values are available during application setup.
Dotenvx::Railtie.instance.load
