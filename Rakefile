require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'github/markup'
require 'redcarpet'
require 'yard'
require 'yard/rake/yardoc_task'

desc 'Don\'t run Rubocop for unsupported versions'
begin
  if RUBY_VERSION >= '2.0.0'
    args = [:spec, :make_bin_executable, :yard, :rubocop]
  else
    args = [:spec, :make_bin_executable, :yard]
  end
end

YARD::Rake::YardocTask.new do |t|
  OTHER_PATHS = %w()
  t.files = ['lib/**/*.rb', 'bin/**/*.rb', OTHER_PATHS]
  t.options = %w(--markup-provider=redcarpet --markup=markdown --main=README.md --files CHANGELOG.md)
end

Rubocop::RakeTask.new

RSpec::Core::RakeTask.new(:spec) do |r|
  r.pattern = FileList['**/**/*_spec.rb']
end

# desc 'Calculate technical debt'
# task :calculate_debt do
#   `/usr/bin/env ruby scripts/tech_debt.rb`
# end

desc 'Make all plugins executable'
task :make_bin_executable do
  `chmod -R +x bin/*`
end

task default: args
