# frozen_string_literal: true
require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'pathname'
require 'rubygems/package'

module RubyRelease
  PLATFORMS = %w[aarch64-linux arm64-darwin x86_64-darwin x86_64-linux].freeze
  REPOSITORY = 'https://github.com/dotenvx/forge'

  def self.expected(version)
    PLATFORMS.to_h { |platform| ["dotenvx-#{version}-#{platform}.gem", ['dotenvx', platform]] }
      .merge("dotenvx-rails-#{version}.gem" => ['dotenvx-rails', 'ruby'])
  end

  def self.validate(root, tag)
    root = Pathname(root)
    source = JSON.parse(root.join('FORGE_SOURCE.json').read)
    version = source.fetch('version')
    abort 'Invalid Ruby release version' unless version.match?(/\A\d+\.\d+\.\d+\z/)
    abort 'Release tag/version mismatch' unless tag == "v#{version}" && source['tag'] == "ruby-v#{version}"
    abort 'Invalid Forge source identity' unless source['repository'] == REPOSITORY && source.fetch('commit').match?(/\A[0-9a-f]{40}\z/)
    files = expected(version)
    abort 'Expected exactly four native gems and one Rails gem' unless Dir.glob(root.join('pkg/*.gem')).map { |p| File.basename(p) }.sort == files.keys.sort && source.fetch('gems').keys.sort == files.keys.sort
    files.each do |file, (name, platform)|
      archive = root.join('pkg', file)
      abort "Checksum mismatch: #{file}" unless Digest::SHA256.file(archive).hexdigest == source['gems'][file]
      package = Gem::Package.new(archive.to_s)
      package.verify
      spec = package.spec
      abort "Unexpected gem identity: #{file}" unless spec.name == name && spec.version.to_s == version && spec.platform.to_s == platform
      abort "Gem must not compile on install: #{file}" unless spec.extensions.empty? && spec.runtime_dependencies.none? { |dep| dep.name == 'rb_sys' }
      if name == 'dotenvx'
        extension = platform.end_with?('darwin') ? 'bundle' : 'so'
        abort "Missing native extension: #{file}" unless package.contents.include?("lib/dotenvx/dotenvx_native.#{extension}")
      else
        dependency = spec.runtime_dependencies.find { |dep| dep.name == 'dotenvx' }
        abort 'Rails gem must pin the matching native gem version' unless dependency&.requirement&.requirements == [['=', Gem::Version.new(version)]]
      end
    end
    source
  end

  def self.stage(source, destination, gems)
    source, destination = Pathname(source), Pathname(destination)
    # Read the generated version constant without evaluating arbitrary source.
    version = source.join('lib/dotenvx/version.rb').read[/VERSION\s*=\s*["'](\d+\.\d+\.\d+)["']/, 1]
    abort 'Invalid Ruby source version' unless version
    commit = ENV.fetch('GITHUB_SHA')
    tag = ENV.fetch('GITHUB_REF_NAME')
    abort 'Forge release tag/version mismatch' unless tag == "ruby-v#{version}"
    FileUtils.mkdir_p(destination.join('pkg'))
    expected(version).each_key do |file|
      FileUtils.cp(Pathname(gems).join(file), destination.join('pkg', file))
    end
    # Stale or unexpected artifacts must fail rather than disappear in staging.
    abort 'Unexpected gem artifacts' unless Dir.glob(File.join(gems, '*.gem')).map { |p| File.basename(p) }.sort == expected(version).keys.sort
    %w[README.md CHANGELOG.md LICENSE].each { |file| FileUtils.cp(source.join(file), destination.join(file)) }
    Dir.glob(source.join('lib/**/*.rb')).each do |file|
      output = destination.join(Pathname(file).relative_path_from(source))
      FileUtils.mkdir_p(output.dirname)
      FileUtils.cp(file, output)
    end
    FileUtils.mkdir_p(destination.join('.github/workflows'))
    FileUtils.mkdir_p(destination.join('.github/scripts'))
    %w[.github/workflows/ci.yml .github/scripts/release.rb .github/scripts/test-native.rb].each do |file|
      FileUtils.cp(source.join(file), destination.join(file))
    end
    manifest = { repository: REPOSITORY, commit: commit, tag: tag, version: version,
      gems: expected(version).keys.sort.to_h { |file| [file, Digest::SHA256.file(destination.join('pkg', file)).hexdigest] } }
    destination.join('FORGE_SOURCE.json').write(JSON.pretty_generate(manifest) + "\n")
    validate(destination, "v#{version}")
  end

  def self.publish(root, tag, fetch: nil, push: nil)
    source = validate(root, tag)
    env = ENV
    authorized = env['GITHUB_ACTIONS'] == 'true' && env['GITHUB_REPOSITORY'] == 'dotenvx/dotenvx-ruby' &&
      ((env['GITHUB_EVENT_NAME'] == 'push' && env['GITHUB_REF'] == "refs/tags/#{tag}") ||
       (env['GITHUB_EVENT_NAME'] == 'workflow_dispatch' && env['PUBLISH'] == 'true'))
    abort 'Publish only from the matching public Ruby release workflow' unless authorized
    fetch ||= lambda do |name|
      uri = URI("https://rubygems.org/api/v1/versions/#{name}.json")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) { |http| http.get(uri.request_uri) }
      abort "RubyGems metadata lookup failed for #{name}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end
    push ||= ->(file) { system('gem', 'push', file, '--host', 'https://rubygems.org', exception: true) }
    versions = %w[dotenvx dotenvx-rails].to_h { |name| [name, fetch.call(name)] }
    pending = expected(source.fetch('version')).filter_map do |file, (name, platform)|
      existing = versions.fetch(name).find { |v| v['number'] == source['version'] && v['platform'] == platform }
      if existing
        abort "Already published with different contents: #{file}" unless existing['sha'] == source['gems'][file]
        puts "Already published #{file} (matching SHA-256)"
        nil
      else
        File.join(root, 'pkg', file)
      end
    end
    # Validate every existing remote checksum before pushing any missing gem.
    pending.each { |file| push.call(file) }
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.shift
  when 'stage' then RubyRelease.stage(*ARGV)
  when 'verify' then RubyRelease.validate('.', ENV.fetch('RELEASE_TAG')); puts 'Ruby release contents verified'
  when 'publish' then RubyRelease.publish('.', ENV.fetch('RELEASE_TAG'))
  else abort 'Use stage SOURCE DESTINATION GEMS, verify, or publish'
  end
end
