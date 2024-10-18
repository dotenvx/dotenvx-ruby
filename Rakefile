#!/usr/bin/env rake

require "bundler/gem_helper"

namespace "dotenvx" do
  Bundler::GemHelper.install_tasks name: "dotenvx"
end

class DotenvxRailsGemHelper < Bundler::GemHelper
  def guard_already_tagged
    # noop
  end

  def tag_version
    # noop
  end
end

namespace "dotenvx-rails" do
  DotenvxRailsGemHelper.install_tasks name: "dotenvx-rails"
end

task build: ["dotenvx:build", "dotenvx-rails:build"]
task install: ["dotenvx:install", "dotenvx-rails:install"]
task release: ["dotenvx:release", "dotenvx-rails:release"]

require "rspec/core/rake_task"

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w[--color]
  t.verbose = false
end

task :default => :spec
