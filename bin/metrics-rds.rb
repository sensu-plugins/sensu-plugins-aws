#! /usr/bin/env ruby
#
# rds-metrics
#
# DESCRIPTION:
#   Gets RDS metrics from CloudWatch and puts them in Graphite for longer term storage
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   rds-metrics --aws-region eu-west-1
#   rds-metrics --aws-region eu-west-1 --name sr2x8pbti0eon1
#
# NOTES:
#   Returns all RDS statistics for all RDS instances in this account unless you specify --name
#
# LICENSE:
#   Copyright 2013 Bashton Ltd http://www.bashton.com/
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'time'

class RDSMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :aws_access_key,
         short:       '-a AWS_ACCESS_KEY',
         long:        '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default:     ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short:       '-k AWS_SECRET_KEY',
         long:        '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default:     ENV['AWS_SECRET_KEY']

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'eu-central-1'

  option :db_instance_id,
         short:       '-i N',
         long:        '--db-instance-id NAME',
         description: 'DB instance identifier'

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     60,
         proc:        proc(&:to_i),
         description: 'CloudWatch metric statistics period'

  option :statistics,
         short:       '-S N',
         long:        '--statistics NAME',
         default:     :average,
         proc:        proc { |a| a.downcase.intern },
         description: 'CloudWatch statistics method'

  def rds
    @rds = Aws::RDS::Client.new(aws_config)
  end

  def cloud_watch
    @cloud_watch = Aws::CloudWatch::Client.new(aws_config)
  end

  def find_db_instance(id)
    db = rds.describe_db_instances.db_instances.detect { |db_instance| db_instance.db_instance_identifier == id }
    unknown 'DB instance not found.' if db.nil?
    db
  end

  def cloud_watch_metric(metric_name, value)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/RDS',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'DBInstanceIdentifier',
          value: value
        }
      ],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      statistics: [config[:statistics].to_s.capitalize],
      period: config[:period]
    )
  end

  def run
    statistic_type = {
      'CPUUtilization' => 'Average',
      'DatabaseConnections' => 'Average',
      'FreeStorageSpace' => 'Average',
      'ReadIOPS' => 'Average',
      'ReadLatency' => 'Average',
      'ReadThroughput' => 'Average',
      'WriteIOPS' => 'Average',
      'WriteLatency' => 'Average',
      'WriteThroughput' => 'Average',
      'ReplicaLag' => 'Average',
      'SwapUsage' => 'Average',
      'BinLogDiskUsage' => 'Average',
      'DiskQueueDepth' => 'Average'
    }

    @db_instance  = find_db_instance config[:db_instance_id]
    @message      = "#{config[:db_instance_id]}: "

    result = {}

    rdsname = @db_instance.db_instance_identifier

    statistic_type.each do |key, _value|
      r = cloud_watch_metric key, rdsname
      result[rdsname + '.' + key] = r[:datapoints][0] unless r[:datapoints][0].nil?
    end
    unless result.nil?
      result.each do |key, value|
        output key.downcase.to_s, value.average, value[:timestamp].to_i
      end
    end
    exit
  end
end
