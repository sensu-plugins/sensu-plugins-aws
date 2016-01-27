#! /usr/bin/env ruby
#
# check-instance-count
#
# DESCRIPTION:
#   This plugin checks that the filtered instance list is above a threshold
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Leon Gibat, brendan.gibat@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class CheckInstanceCount < Sensu::Plugin::Check::CLI
  include Common
  include Filter

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :filter,
         short: '-f FILTER',
         long: '--filter FILTER',
         description: 'String representation of the filter to apply',
         default: '{}'

  option :timeout,
         description: 'Ping timeout in seconds',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         default: 5,
         proc: proc(&:to_i)

  option :critical,
         description: 'Count to critical at or below',
         short: '-c COUNT',
         long: '--critical COUNT',
         default: 0,
         proc: proc(&:to_i)

  option :warning,
         description: 'Count to warn at or below',
         short: '-w WARNING',
         long: '--warning WARNING',
         default: 0,
         proc: proc(&:to_i)

  option :invert,
         description: 'Invert thresholds to be maximums instead of minimums',
         short: '-i',
         long: '--invert',
         default: false,
         boolean: true

  def run
    begin
      aws_config
      client = Aws::EC2::Client.new

      filter = Filter.parse(config[:filter])

      options = { filters: filter }

      errors = []
      instance_ids = []
      data = client.describe_instances(options)

      count = data[:reservations].map {|r| r[:instances].count}.inject{|sum,x| sum + x }
      if count.nil?
        count = 0
      end
      if config[:invert]
        if count > config[:critical]
          critical "Count #{count} was above critical threshold"
        elsif count > warning[:critical]
          warning "Count #{count} was above warning threshold"
        end
      else
        if count <= config[:critical]
          critical "Count #{count} was below or at critical threshold"
        elsif count <= config[:warning]
          warning "Count #{count} was below or at warning threshold"
        end
      end
    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    if errors.empty?
      ok "Instances checked: #{instance_ids.join(",")}"
    else
      message = errors.join(",")
      if config[:critical_response]
        critical message
      else
        warning message
      end
    end
  end
end
