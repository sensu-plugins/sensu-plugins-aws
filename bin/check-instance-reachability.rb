#! /usr/bin/env ruby
#
# check-instance-reachability
#
# DESCRIPTION:
#   This plugin looks up all instances from a filter set and pings
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

class CheckInstanceReachability < Sensu::Plugin::Check::CLI
  include Common
  include Filter

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

  option :count,
         description: 'Ping count',
         short: '-c COUNT',
         long: '--count COUNT',
         default: 1,
         proc: proc(&:to_i)

  option :critical_response,
         description: 'Flag if the response should error on failures',
         short: '-r',
         long: '--critical-response',
         boolean: true,
         default: false

  def run
    begin
      aws_config
      client = Aws::EC2::Client.new

      filter = Filter.parse(config[:filter])

      options = { filters: filter }

      errors = []
      instance_ids = []
      data = client.describe_instances(options)

      data[:reservations].each do |res|
        res[:instances].each do |i|
          instance_ids << i[:instance_id]
          `ping -c #{config[:count]} -W #{config[:timeout]} #{i[:private_ip_address]}`
          if $CHILD_STATUS.to_i > 0
            errors << "Could not reach #{i[:instance_id]}"
          end
        end
      end
    rescue StandardError => e
      puts "Error: exception: #{e}"
      critical
    end
    if errors.empty?
      ok "Instances checked: #{instance_ids.join(',')}"
    else
      message = errors.join(',')
      if config[:critical_response]
        critical message
      else
        warning message
      end
    end
  end
end
