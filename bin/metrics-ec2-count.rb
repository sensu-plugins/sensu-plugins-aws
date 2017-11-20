#!/usr/bin/env ruby
#
# metrics-ec2-count
#
# DESCRIPTION:
#   This plugin retrieves number of EC2 instances.
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
#   # get metrics on the status of all instances in the region
#   metrics-ec2-count.rb -t status
#
#   # get metrics on all instance types in the region
#   metrics-ec2-count.rb -t instance
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Tim Smith, tsmith@chef.io
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class EC2Metrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sensu.aws.ec2'

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :type,
         short: '-t METRIC type',
         long: '--type METRIC type',
         description: 'Count by type: status, instance',
         default: 'instance'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def by_instances_status(client)
    if config[:scheme] == 'sensu.aws.ec2'
      config[:scheme] += '.count'
    end

    options = { include_all_instances: true }
    status_data = client.describe_instance_status(options)

    total = status_data.instance_statuses.count
    status = {}

    unless total.nil?
      status_data.instance_statuses.each do |value|
        stat = value.instance_state.name
        status[stat] = if status[stat].nil?
                         1
                       else
                         status[stat] + 1
                       end
      end
    end

    unless status_data.nil? # rubocop: disable Style/GuardClause
      # We only return data when we have some to return
      output config[:scheme] + '.total', total
      status.each do |name, count|
        output config[:scheme] + ".#{name}", count
      end
    end
  end

  def by_instances_type(client)
    if config[:scheme] == 'sensu.aws.ec2'
      config[:scheme] += '.types'
    end

    data = {}

    instances = client.describe_instances
    instances.reservations.each do |i|
      i.instances.each do |instance|
        type = instance.instance_type
        data[type] = if data[type].nil?
                       1
                     else
                       data[type] + 1
                     end
      end
    end

    unless data.nil? # rubocop: disable Style/GuardClause
      # We only return data when we have some to return
      data.each do |name, count|
        output config[:scheme] + ".#{name}", count
      end
    end
  end

  def run
    begin
      client = Aws::EC2::Client.new(aws_config)

      if config[:type] == 'instance'
        by_instances_type(client)
      elsif config[:type] == 'status'
        by_instances_status(client)
      end
    rescue StandardError => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
