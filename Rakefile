#!/usr/bin/env rake

require "rb_sys/extensiontask"
require "fileutils"
require "rbconfig"
require "rubygems/package"

require "rspec/core/rake_task"

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w[--color]
  t.verbose = false
end

gemspec = Gem::Specification.load("dotenvx.gemspec")

RbSys::ExtensionTask.new("dotenvx_native", gemspec) do |ext|
  ext.ext_dir = "ext/dotenvx"
  ext.lib_dir = "lib/dotenvx"
end

task build: :compile
task default: %i[compile spec]

namespace :package do
  desc "Build the platform-specific dotenvx gem with its Rust extension"
  task native: :compile do
    local = Gem::Platform.local
    platform = if local.os == "darwin"
      Gem::Platform.new([local.cpu, local.os, nil])
    else
      local
    end
    extension = "lib/dotenvx/dotenvx_native.#{RbConfig::CONFIG.fetch("DLEXT")}"
    abort "missing compiled extension: #{extension}" unless File.file?(extension)

    native_spec = gemspec.dup
    native_spec.platform = platform
    native_spec.extensions = []
    native_spec.files = native_spec.files.reject do |file|
      file == "Cargo.toml" ||
        file == "Cargo.lock" ||
        file.start_with?("ext/dotenvx/")
    end
    native_spec.files |= [extension]
    native_spec.dependencies.delete_if { |dependency| dependency.name == "rb_sys" }

    FileUtils.mkdir_p("pkg")
    gem_file = Gem::Package.build(native_spec)
    FileUtils.mv(gem_file, File.join("pkg", File.basename(gem_file)))
  end
end
