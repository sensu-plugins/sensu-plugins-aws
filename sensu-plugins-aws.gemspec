lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'
require_relative 'lib/sensu-plugins-aws'

Gem::Specification.new do |s| # rubocop:disable Metrics/BlockLength
  s.authors                = ['Sensu-Plugins and contributors']
  s.date                   = Date.today.to_s
  s.description            = 'This plugin provides native AWS instrumentation
                              for monitoring and metrics collection, including:
                              health and metrics for various AWS services, such
                              as EC2, RDS, ELB, and more, as well as handlers
                              for EC2, SES, and SNS.'
  s.email                  = '<sensu-users@googlegroups.com>'
  s.executables            = Dir.glob('bin/**/*.rb').map { |file| File.basename(file) }
  s.files                  = Dir.glob('{bin,lib}/**/*') + %w[LICENSE README.md CHANGELOG.md]
  s.homepage               = 'https://github.com/sensu-plugins/sensu-plugins-aws'
  s.license                = 'MIT'
  s.metadata               = { 'maintainer'         => 'sensu-plugin',
                               'development_status' => 'active',
                               'production_status'  => 'unstable - testing recommended',
                               'release_draft'      => 'false',
                               'release_prerelease' => 'false' }
  s.name                   = 'sensu-plugins-aws'
  s.platform               = Gem::Platform::RUBY
  s.post_install_message   = 'You can use the embedded Ruby by setting EMBEDDED_RUBY=true in /etc/default/sensu'
  s.require_paths          = ['lib']
  s.required_ruby_version  = '>= 2.3.0'
  s.summary                = 'Sensu plugins for working with an AWS environment'
  s.test_files             = s.files.grep(%r{^(test|spec|features)/})
  s.version                = SensuPluginsAWS::Version::VER_STRING

  s.add_runtime_dependency 'sensu-plugin', '~> 4.0'

  s.add_runtime_dependency 'aws-sdk-autoscaling',             '~> 1.20.0'
  s.add_runtime_dependency 'aws-sdk-cloudfront',              '~> 1.15.0'
  s.add_runtime_dependency 'aws-sdk-cloudwatch',              '~> 1.19.0'
  s.add_runtime_dependency 'aws-sdk-configservice',           '~> 1.26.0'
  s.add_runtime_dependency 'aws-sdk-core',                    '~> 3.48.0'
  s.add_runtime_dependency 'aws-sdk-directconnect',           '~> 1.16.0'
  s.add_runtime_dependency 'aws-sdk-dynamodb',                '~> 1.25.0'
  s.add_runtime_dependency 'aws-sdk-ec2',                     '~> 1.78.0'
  s.add_runtime_dependency 'aws-sdk-ecs',                     '~> 1.36.0'
  s.add_runtime_dependency 'aws-sdk-efs',                     '~> 1.13.0'
  s.add_runtime_dependency 'aws-sdk-elasticache',             '~> 1.14.0'
  s.add_runtime_dependency 'aws-sdk-elasticbeanstalk',        '~> 1.19.0'
  s.add_runtime_dependency 'aws-sdk-elasticloadbalancing',    '~> 1.12.0'
  s.add_runtime_dependency 'aws-sdk-elasticloadbalancingv2',  '~> 1.26.0'
  s.add_runtime_dependency 'aws-sdk-emr',                     '~> 1.14.0'
  s.add_runtime_dependency 'aws-sdk-iam',                     '~> 1.18.0'
  s.add_runtime_dependency 'aws-sdk-kms',                     '~> 1.16.0'
  s.add_runtime_dependency 'aws-sdk-redshift',                '~> 1.22.0'
  s.add_runtime_dependency 'aws-sdk-route53domains',          '~> 1.11.0'
  s.add_runtime_dependency 'aws-sdk-s3',                      '~> 1.36.0'
  s.add_runtime_dependency 'aws-sdk-ses',                     '~> 1.18.0'
  s.add_runtime_dependency 'aws-sdk-sns',                     '~> 1.12.0'
  s.add_runtime_dependency 'aws-sdk-sqs',                     '~> 1.13.0'
  s.add_runtime_dependency 'aws-sdk-support',                 '~> 1.9.0'
  s.add_runtime_dependency 'erubis',            '2.7.0'
  s.add_runtime_dependency 'fog',               '1.32.0'
  # 1.44 requires xmlrpc which only supports >= ruby 2.3
  # https://github.com/fog/fog-core/issues/206
  s.add_runtime_dependency 'fog-core',          '1.43.0'
  s.add_runtime_dependency 'rest-client',       '1.8.0'
  s.add_runtime_dependency 'right_aws',         '3.1.0'

  s.add_development_dependency 'bundler',                   '~> 1.7'
  s.add_development_dependency 'github-markup',             '~> 3.0'
  s.add_development_dependency 'pry',                       '~> 0.10'
  s.add_development_dependency 'rake',                      '~> 12.3'
  s.add_development_dependency 'redcarpet',                 '~> 3.2'
  s.add_development_dependency 'rspec',                     '~> 3.4'
  s.add_development_dependency 'rubocop',                   '~> 0.51.0'
  s.add_development_dependency 'yard',                      '~> 0.9.11'
end
