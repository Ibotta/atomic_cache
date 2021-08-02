# frozen_string_literal: true
# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'atomic_cache/version'

Gem::Specification.new do |spec|
  spec.name          = 'atomic_cache'
  spec.version       = AtomicCache::VERSION
  spec.authors       = ['Ibotta Developers', 'Titus Stone']
  spec.email         = 'osscompliance@ibotta.com'

  spec.description   = 'A gem which prevents the thundering herd problem through a distributed lock'
  spec.summary       = 'In a nutshell:'\
  '* The key of every cached value includes a timestamp'\
  '* Once a cache key is written to, it is never written over'\
  '* When a newer version of a cached value is available, it is written to a new key'\
  '* When a new value is being generated for a new key only 1 process is allowed to do so at a time'\
  '* While the new value is being generated, other processes read one key older than most recent'\
  
  spec.licenses      = ['Apache-2.0']
  spec.homepage      = 'https://github.com/ibotta/atomic_cache'

  spec.files             = %w( README.md LICENSE )
  spec.files            += Dir.glob("lib/**/*")
  spec.files            += Dir.glob("docs/**/*")
  spec.files            += Dir.glob("spec/**/*")

  spec.require_paths = ['lib']

  # Dev dependencies
  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'gems', '~> 1.0'
  spec.add_development_dependency 'git', '~> 1.3'
  spec.add_development_dependency 'github_changelog_generator', '>= 1.15.0.pre.rc'
  spec.add_development_dependency 'octokit', '~> 4.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov', '~> 0.15'
  spec.add_development_dependency 'timecop', '~> 0.8.1'

  # Dependencies
  spec.add_dependency 'activesupport', '>= 4.2'
  spec.add_dependency 'murmurhash3', '~> 0.1'
end
