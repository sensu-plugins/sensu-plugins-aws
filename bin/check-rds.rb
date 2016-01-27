#! /usr/bin/env ruby
#
# check-rds
#
# DESCRIPTION:
#   Check RDS instance statuses by RDS and CloudWatch API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   Critical if DB instance "sensu-admin-db" is not on ap-northeast-1a
#   check-rds -i sensu-admin-db --availability-zone-critical ap-northeast-1a
#
#   Warning if CPUUtilization is over 80%, critical if over 90%
#   check-rds -i sensu-admin-db --cpu-warning-over 80 --cpu-critical-over 90
#
#   Critical if CPUUtilization is over 90%, maximum of last one hour
#   check-rds -i sensu-admin-db --cpu-critical-over 90 --statistics maximum --period 3600
#
#   Warning if DatabaseConnections are over 100, critical over 120
#   check-rds -i sensu-admin-db --connections-critical-over 120 --connections-warning-over 100 --statistics maximum --period 3600
#
#   Warning if memory usage is over 80%, maximum of last 2 hour
#   specifying "minimum" is intended actually since memory usage is calculated from CloudWatch "FreeableMemory" metric.
#   check-rds -i sensu-admin-db --memory-warning-over 80 --statistics minimum --period 7200
#
#   Disk usage, same as memory
#   check-rds -i sensu-admin-db --disk-warning-over 80 --period 7200
#
#   You can check multiple metrics simultaneously. Highest severity will be reported
#   check-rds -i sensu-admin-db --cpu-warning-over 80 --cpu-critical-over 90 --memory-warning-over 60 --memory-critical-over 80
#
#   You can ignore accept nil values returned for a time periods from Cloudwatch as being an OK.  Amazon falls behind in their
#   metrics from time to time and this prevents false positives
#   check-rds -i sensu-admin-db --cpu-critical-over 90 -n
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 github.com/y13i
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'
require 'time'

class CheckRDS < Sensu::Plugin::Check::CLI
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
         default:     'us-east-1'

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

  option :accept_nil,
         short: '-n',
         long: '--accept_nil',
         description: 'Continue if CloudWatch provides no metrics for the time period',
         default: false

  %w(warning critical).each do |severity|
    option :"availability_zone_#{severity}",
           long:        "--availability-zone-#{severity} AZ",
           description: "Trigger a #{severity} if availability zone is different than given argument"

    %w(cpu memory disk connections).each do |item|
      option :"#{item}_#{severity}_over",
             long:        "--#{item}-#{severity}-over N",
             proc:        proc(&:to_f),
             description: "Trigger a #{severity} if #{item} usage is over a percentage"
    end
  end

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def rds
    @rds ||= AWS::RDS.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::CloudWatch.new aws_config
  end

  def find_db_instance(id)
    db = rds.instances[id]
    unknown 'DB instance not found.' unless db.exists?
    db
  end

  def cloud_watch_metric(metric_name)
    cloud_watch.metrics.with_namespace('AWS/RDS').with_metric_name(metric_name).with_dimensions(name: 'DBInstanceIdentifier', value: @db_instance.id).first
  end

  def statistics_options
    {
      start_time: config[:end_time] - config[:period],
      end_time:   config[:end_time],
      statistics: [config[:statistics].to_s.capitalize],
      period:     config[:period]
    }
  end

  def latest_value(metric, unit)
    values = metric.statistics(statistics_options.merge unit: unit).datapoints.sort_by { |datapoint| datapoint[:timestamp] }

    # handle time periods that are too small to return usable values.  # this is a cozy addition that wouldn't port upstream.
    if values.empty?
      config[:accept_nil] ? ok('Cloudwatch returned no results for time period. Accept nil passed so OK') : unknown('Requested time period did not return values from Cloudwatch. Try increasing your time period.')
    else
      values.last[config[:statistics]]
    end
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def memory_total_bytes(instance_class)
    memory_total_gigabytes = {
      'db.cr1.8xlarge' => 244.0,
      'db.m1.small'    => 1.7,
      'db.m1.medium'   => 3.75,
      'db.m1.large'    => 7.5,
      'db.m1.xlarge'   => 15.0,
      'db.m2.xlarge'   => 17.1,
      'db.m2.2xlarge'  => 34.2,
      'db.m2.4xlarge'  => 68.4,
      'db.m3.medium'   => 3.75,
      'db.m3.large'    => 7.5,
      'db.m3.xlarge'   => 15.0,
      'db.m3.2xlarge'  => 30.0,
      'db.m4.large'    => 8.0,
      'db.m4.xlarge'   => 16.0,
      'db.m4.2xlarge'  => 32.0,
      'db.m4.4xlarge'  => 64.0,
      'db.m4.10xlarge' => 160.0,
      'db.r3.large'    => 15.0,
      'db.r3.xlarge'   => 30.5,
      'db.r3.2xlarge'  => 61.0,
      'db.r3.4xlarge'  => 122.0,
      'db.r3.8xlarge'  => 244.0,
      'db.t1.micro'    => 0.615,
      'db.t2.micro'    => 1,
      'db.t2.small'    => 2,
      'db.t2.medium'   => 4,
      'db.t2.large'    => 8
    }

    memory_total_gigabytes.fetch(instance_class) * 1024**3
  end

  def check_az(severity, expected_az)
    return if @db_instance.availability_zone_name == expected_az
    flag_alert severity, "; AZ is #{@db_instance.availability_zone_name} (expected #{expected_az})"
  end

  def check_cpu(severity, expected_lower_than)
    @cpu_metric ||= cloud_watch_metric 'CPUUtilization'
    @cpu_metric_value ||= latest_value @cpu_metric, 'Percent'
    return if @cpu_metric_value < expected_lower_than
    flag_alert severity, "; CPUUtilization is #{sprintf '%.2f', @cpu_metric_value}% (expected lower than #{expected_lower_than}%)"
  end

  def check_memory(severity, expected_lower_than)
    @memory_metric ||= cloud_watch_metric 'FreeableMemory'
    @memory_metric_value ||= latest_value @memory_metric, 'Bytes'
    @memory_total_bytes ||= memory_total_bytes @db_instance.db_instance_class
    @memory_usage_bytes ||= @memory_total_bytes - @memory_metric_value
    @memory_usage_percentage ||= @memory_usage_bytes / @memory_total_bytes * 100
    return if @memory_usage_percentage < expected_lower_than
    flag_alert severity, "; Memory usage is #{sprintf '%.2f', @memory_usage_percentage}% (expected lower than #{expected_lower_than}%)"
  end

  def check_disk(severity, expected_lower_than)
    @disk_metric ||= cloud_watch_metric 'FreeStorageSpace'
    @disk_metric_value ||= latest_value @disk_metric, 'Bytes'
    @disk_total_bytes ||= @db_instance.allocated_storage * 1024**3
    @disk_usage_bytes ||= @disk_total_bytes - @disk_metric_value
    @disk_usage_percentage ||= @disk_usage_bytes / @disk_total_bytes * 100
    return if @disk_usage_percentage < expected_lower_than
    flag_alert severity, "; Disk usage is #{sprintf '%.2f', @disk_usage_percentage}% (expected lower than #{expected_lower_than}%)"
  end

  def check_connections(severity, expected_lower_than)
    @connections_metric ||= cloud_watch_metric 'DatabaseConnections'
    @connections_metric_value ||= latest_value @connections_metric, 'Count'
    return if @connections_metric_value < expected_lower_than
    flag_alert severity, "; DatabaseConnections are #{sprintf '%d', @connections_metric_value} (expected lower than #{expected_lower_than})"
  end

  def run
    if config[:db_instance_id].nil? || config[:db_instance_id].empty?
      unknown 'No DB instance provided.  See help for usage details'
    end

    @db_instance  = find_db_instance config[:db_instance_id]
    @message      = "#{config[:db_instance_id]}: "
    @severities   = {
      critical: false,
      warning:  false
    }

    @severities.keys.each do |severity|
      check_az severity, config[:"availability_zone_#{severity}"] if config[:"availability_zone_#{severity}"]

      %w(cpu memory disk connections).each do |item|
        send "check_#{item}", severity, config[:"#{item}_#{severity}_over"] if config[:"#{item}_#{severity}_over"]
      end
    end

    if %w(cpu memory disk connections).any? { |item| %w(warning critical).any? { |severity| config[:"#{item}_#{severity}_over"] } }
      @message += "(#{config[:statistics].to_s.capitalize} within #{config[:period]}s "
      @message += "between #{config[:end_time] - config[:period]} to #{config[:end_time]})"
    end

    if @severities[:critical]
      critical @message
    elsif @severities[:warning]
      warning @message
    else
      ok @message
    end
  end
end
