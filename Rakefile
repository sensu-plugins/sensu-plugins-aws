require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'github/markup'
require 'redcarpet'
require 'yard'
require 'yard/rake/yardoc_task'

args = [:spec, :yard, :rubocop]

YARD::Rake::YardocTask.new do |t|
  OTHER_PATHS = %w()
  t.files = ['lib/**/*.rb', 'bin/**/*.rb', OTHER_PATHS]
  t.options = %w(--markup-provider=redcarpet --markup=markdown --main=README.md --files CHANGELOG.md,CONTRIBUTING.md)
end

RuboCop::RakeTask.new

# Prevent environment pollution when running tests.
ENV['AWS_SECRET_KEY'] = nil
ENV['AWS_SECRET_ACCESS_KEY'] = nil
ENV['AWS_ACCESS_KEY'] = nil
ENV['AWS_ACCESS_KEY_ID'] = nil

RSpec::Core::RakeTask.new(:spec) do |r|
  r.pattern = FileList['**/**/*_spec.rb']
end

task default: args
