#! /usr/bin/env ruby
#
# check-rds-cpu_balance
#
# DESCRIPTION:
#   This plugin retrieves the value of the cpu balance for RDS instance
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
#   ./check-rds-cpu_balance -c 20
#
# NOTES:
#  Based on check-ec2-cpu_balance.rb script (Shane Starcher)
#
# LICENSE:
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class RDSCpuBalance < Sensu::Plugin::Check::CLI
  include Common

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

  def data(instance)
    client = Aws::CloudWatch::Client.new
    stats = 'Average'
    period = 60
    resp = client.get_metric_statistics(
      namespace: 'AWS/RDS',
      metric_name: 'CPUCreditBalance',
      dimensions: [{
        name: 'DBInstanceIdentifier',
        value: instance
      }],
      start_time: Time.now - period * 10,
      end_time: Time.now,
      period: period,
      statistics: [stats]
    )

    return resp.datapoints.first.send(stats.downcase) unless resp.datapoints.first.nil?
  end

  def run
    rds = Aws::RDS::Client.new
    instances = rds.describe_db_instances

    messages = "\n"
    level = 0
    instances.db_instances.each do |db_instance|
      next unless db_instance.db_instance_class.start_with? 'db.t2.'
      id = db_instance.db_instance_identifier
      result = data id
      unless result.nil?
        if result < config[:critical]
          level = 2
          messages << "#{id} is below critical threshold [#{result} < #{config[:critical]}]\n"
        elsif config[:warning] && result < config[:warning]
          level = 1 if level == 0
          messages << "#{id} is below warning threshold [#{result} < #{config[:warning]}]\n"
        end
      end
    end
    ok messages if level == 0
    warning messages if level == 1
    critical messages if level == 2
  end
end
