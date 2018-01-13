require 'bundler/gem_tasks'
require 'github/markup'
require 'redcarpet'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'

YARD::Rake::YardocTask.new do |t|
  OTHER_PATHS = %w[].freeze
  t.files = ['lib/**/*.rb', 'bin/**/*.rb', OTHER_PATHS]
  t.options = %w[--markup-provider=redcarpet --markup=markdown --main=README.md --files CHANGELOG.md]
end

RuboCop::RakeTask.new

RSpec::Core::RakeTask.new(:spec) do |r|
  r.pattern = FileList['**/**/*_spec.rb']
end

desc 'Make all plugins executable'
task :make_bin_executable do
  `chmod -R +x bin/*`
end

desc 'Test for binstubs'
task :check_binstubs do
  unless Dir.glob('bin/**/*.rb').empty?
    bin_list = Gem::Specification.load('sensu-plugins-aws.gemspec').executables
    bin_list.each do |b|
      `which #{ b }`
      unless $CHILD_STATUS.success?
        puts "#{b} was not a binstub"
        exit
      end
    end
  end
end

task default: %i[spec make_bin_executable yard rubocop check_binstubs]
