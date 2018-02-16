require 'atomic_cache/version'
require "github_changelog_generator/task"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'Ibotta'
  config.project = 'atomic_cache'
  config.future_release = AtomicCache::VERSION
end

task :default => :spec
