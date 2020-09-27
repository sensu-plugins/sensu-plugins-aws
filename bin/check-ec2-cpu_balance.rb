#! /usr/bin/env ruby
#
# check-ec2-cpu_balance
#
# DESCRIPTION:
#   This plugin retrieves the value of the cpu balance for all servers
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
#   ./check-ec2-cpu_balance -c 20
#   ./check-ec2-cpu_balance -w 25 -c 20
#   ./check-ec2-cpu_balance -c 20 -t 'Name'
#   ./check-ec2-cpu_balance -c 20 -t 'Name' -F "{name:tag-value,values:[infrastructure]}"
#
# NOTES:
#
# LICENSE:
#   Shane Starcher
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws/filter'

class EC2CpuBalance < Sensu::Plugin::Check::CLI
  include Common
  include Filter

  option :critical,
         description: 'Trigger a critical when value is below VALUE',
         short: '-c VALUE',
         long: '--critical VALUE',
         proc: proc(&:to_f),
         required: true

  option :warning,
         description: 'Trigger a warning when value is below VALUE',
         short: '-w VALUE',
         long: '--warning VALUE',
         proc: proc(&:to_f)

  option :aws_region,
         short: '-r R',
         long: '--region REGION',
         description: 'AWS region',
         default: 'us-east-1'

  option :tag,
         description: 'Add instance TAG value to warn/critical message.',
         short: '-t TAG',
         long: '--tag TAG'

  option :instance_families,
         description: 'List of burstable instance families to check. Default to t2,t3',
         short: '-f t2,t3',
         long: '--instance-families t2,t3',
         proc: proc { |x| x.split(',') },
         default: %w[t2 t3]

  option :filter,
         short: '-F FILTER',
         long: '--filter FILTER',
         description: 'String representation of the filter to apply',
         default: '{}'

  def data(instance)
    client = Aws::CloudWatch::Client.new
    stats = 'Average'
    period = 60
    resp = client.get_metric_statistics(
      namespace: 'AWS/EC2',
      metric_name: 'CPUCreditBalance',
      dimensions: [
        {
          name: 'InstanceId',
          value: instance
        }
      ],
      start_time: Time.now - period * 10,
      end_time: Time.now,
      period: period,
      statistics: [stats]
    )

    return resp.datapoints.first.send(stats.downcase) unless resp.datapoints.first.nil?
  end

  def instance_tag(instance, tag_name)
    tag = instance.tags.select { |t| t.key == tag_name }.first
    tag.nil? ? '' : tag.value
  end

  def run
    filters = Filter.parse(config[:filter])
    filters.push(
      name: 'instance-state-name',
      values: ['running']
    )
    ec2 = Aws::EC2::Client.new
    instances = ec2.describe_instances(
      filters: filters
    )

    messages = "\n"
    level = 0
    instances.reservations.each do |reservation|
      reservation.instances.each do |instance|
        next unless instance.instance_type.start_with?(*config[:instance_families])
        id = instance.instance_id
        result = data id
        tag = config[:tag] ? " (#{instance_tag(instance, config[:tag])})" : ''
        unless result.nil?
          if result < config[:critical]
            level = 2
            messages << "#{id}#{tag} is below critical threshold [#{result} < #{config[:critical]}]\n"
          elsif config[:warning] && result < config[:warning]
            level = 1 if level.zero?
            messages << "#{id}#{tag} is below warning threshold [#{result} < #{config[:warning]}]\n"
          end
        end
      end
    end
    ok messages if level.zero?
    warning messages if level == 1
    critical messages if level == 2
  end
end
