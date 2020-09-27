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
#   gem: aws-sdk
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
#   Warning if IOPS are over 100, critical over 200
#   check-rds -i sensu-admin-db --iops-critical-over 200 --iops-warning-over 100 --period 300
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
require 'aws-sdk'
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

  option :role_arn,
         long:        '--role-arn ROLE_ARN',
         description: 'AWS role arn of the role of the third party account to switch to',
         default:     false

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :db_instance_id,
         short:       '-i N',
         long:        '--db-instance-id NAME',
         description: 'DB instance identifier'

  option :db_cluster_id,
         short:       '-l N',
         long:        '--db-cluster-id NAME',
         description: 'DB cluster identifier'

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     180,
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

  %w[warning critical].each do |severity|
    option :"availability_zone_#{severity}",
           long:        "--availability-zone-#{severity} AZ",
           description: "Trigger a #{severity} if availability zone is different than given argument"

    %w[cpu memory disk connections iops].each do |item|
      option :"#{item}_#{severity}_over",
             long:        "--#{item}-#{severity}-over N",
             proc:        proc(&:to_f),
             description: "Trigger a #{severity} if #{item} usage is over a percentage"
    end
  end

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def role_credentials
    @role_credentials = Aws::AssumeRoleCredentials.new(
      client: Aws::STS::Client.new(aws_config),
      role_arn: config[:role_arn],
      role_session_name: "role@#{Time.now.to_i}"
    )
  end

  def rds
    @rds ||= config[:role_arn] ? Aws::RDS::Client.new(credentials: role_credentials, region: aws_config[:region]) : Aws::RDS::Client.new(aws_config)
  end

  def cloud_watch
    @cloud_watch ||= config[:role_arn] ? Aws::CloudWatch::Client.new(credentials: role_credentials, region: aws_config[:region]) : Aws::CloudWatch::Client.new(aws_config)
  end

  def find_db_instance(id)
    db = rds.describe_db_instances.db_instances.detect { |db_instance| db_instance.db_instance_identifier == id }
    unknown 'DB instance not found.' if db.nil?
    db
  end

  def find_db_cluster_writer(id)
    wr = rds.describe_db_clusters(db_cluster_identifier: id).db_clusters[0].db_cluster_members.detect(&:is_cluster_writer).db_instance_identifier
    unknown 'DB cluster not found.' if wr.nil?
    wr
  end

  def cloud_watch_metric(metric_name, unit)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/RDS',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'DBInstanceIdentifier',
          value: @db_instance.db_instance_identifier
        }
      ],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      statistics: [config[:statistics].to_s.capitalize],
      period: config[:period],
      unit: unit
    )
  end

  def latest_value(metric)
    values = metric.datapoints.sort_by { |datapoint| datapoint[:timestamp] }

    # handle time periods that are too small to return usable values.  # this is a cozy addition that wouldn't port upstream.
    if values.empty?
      config[:accept_nil] ? ok('Cloudwatch returned no results for time period. Accept nil passed so OK') : unknown('Requested time period did not return values from Cloudwatch. Try increasing your time period.')
    else
      values.last[config[:statistics]]
    end
  end

  def memory_total_bytes(instance_class)
    memory_total_gigabytes = {
      'db.cr1.8xlarge'  => 244.0,
      'db.m1.small'     => 1.7,
      'db.m1.medium'    => 3.75,
      'db.m1.large'     => 7.5,
      'db.m1.xlarge'    => 15.0,
      'db.m2.xlarge'    => 17.1,
      'db.m2.2xlarge'   => 34.2,
      'db.m2.4xlarge'   => 68.4,
      'db.m3.medium'    => 3.75,
      'db.m3.large'     => 7.5,
      'db.m3.xlarge'    => 15.0,
      'db.m3.2xlarge'   => 30.0,
      'db.m4.large'     => 8.0,
      'db.m4.xlarge'    => 16.0,
      'db.m4.2xlarge'   => 32.0,
      'db.m4.4xlarge'   => 64.0,
      'db.m4.10xlarge'  => 160.0,
      'db.m4.16xlarge'  => 256.0,
      'db.m5.large'     => 8.0,
      'db.m5.xlarge'    => 16.0,
      'db.m5.2xlarge'   => 32.0,
      'db.m5.4xlarge'   => 64.0,
      'db.m5.12xlarge'  => 192.0,
      'db.m5.24xlarge'  => 384.0,
      'db.r3.large'     => 15.0,
      'db.r3.xlarge'    => 30.5,
      'db.r3.2xlarge'   => 61.0,
      'db.r3.4xlarge'   => 122.0,
      'db.r3.8xlarge'   => 244.0,
      'db.r4.large'     => 15.25,
      'db.r4.xlarge'    => 30.5,
      'db.r4.2xlarge'   => 61.0,
      'db.r4.4xlarge'   => 122.0,
      'db.r4.8xlarge'   => 244.0,
      'db.r4.16xlarge'  => 488.0,
      'db.r5.large'     => 16.0,
      'db.r5.xlarge'    => 32.0,
      'db.r5.2xlarge'   => 64.0,
      'db.r5.4xlarge'   => 128.0,
      'db.r5.12xlarge'  => 384.0,
      'db.r5.24xlarge'  => 768.0,
      'db.t1.micro'     => 0.615,
      'db.t2.micro'     => 1.0,
      'db.t2.small'     => 2.0,
      'db.t2.medium'    => 4.0,
      'db.t2.large'     => 8.0,
      'db.t2.xlarge'    => 16.0,
      'db.t2.2xlarge'   => 32.0,
      'db.t3.micro'     => 1.0,
      'db.t3.small'     => 2.0,
      'db.t3.medium'    => 4.0,
      'db.t3.large'     => 8.0,
      'db.t3.xlarge'    => 16.0,
      'db.t3.2xlarge'   => 32.0,
      'db.x1.16xlarge'  => 976.0,
      'db.x1.32xlarge'  => 1952.0,
      'db.x1e.xlarge'   => 122.0,
      'db.x1e.2xlarge'  => 244.0,
      'db.x1e.4xlarge'  => 488.0,
      'db.x1e.8xlarge'  => 976.0,
      'db.x1e.16xlarge' => 1952.0,
      'db.x1e.32xlarge' => 3904.0
    }

    memory_total_gigabytes.fetch(instance_class) * 1024**3
  end

  def check_az(severity, expected_az)
    return if @db_instance.availability_zone == expected_az
    @severities[severity] = true
    "; AZ is #{@db_instance.availability_zone} (expected #{expected_az})"
  end

  def check_cpu(severity, expected_lower_than)
    cpu_metric ||= cloud_watch_metric 'CPUUtilization', 'Percent'
    cpu_metric_value ||= latest_value cpu_metric
    return if cpu_metric_value < expected_lower_than
    @severities[severity] = true
    "; CPUUtilization is #{sprintf '%.2f', cpu_metric_value}% (expected lower than #{expected_lower_than}%)"
  end

  def check_memory(severity, expected_lower_than)
    memory_metric ||= cloud_watch_metric 'FreeableMemory', 'Bytes'
    memory_metric_value ||= latest_value memory_metric
    memory_total_bytes ||= memory_total_bytes @db_instance.db_instance_class
    memory_usage_bytes ||= memory_total_bytes - memory_metric_value
    memory_usage_percentage ||= memory_usage_bytes / memory_total_bytes * 100
    return if memory_usage_percentage < expected_lower_than
    @severities[severity] = true
    "; Memory usage is #{sprintf '%.2f', memory_usage_percentage}% (expected lower than #{expected_lower_than}%)"
  end

  def check_disk(severity, expected_lower_than)
    disk_metric ||= cloud_watch_metric 'FreeStorageSpace', 'Bytes'
    disk_metric_value ||= latest_value disk_metric
    disk_total_bytes ||= @db_instance.allocated_storage * 1024**3
    disk_usage_bytes ||= disk_total_bytes - disk_metric_value
    disk_usage_percentage ||= disk_usage_bytes / disk_total_bytes * 100
    return if disk_usage_percentage < expected_lower_than
    @severities[severity] = true
    "; Disk usage is #{sprintf '%.2f', disk_usage_percentage}% (expected lower than #{expected_lower_than}%)"
  end

  def check_connections(severity, expected_lower_than)
    connections_metric ||= cloud_watch_metric 'DatabaseConnections', 'Count'
    connections_metric_value ||= latest_value connections_metric
    return if connections_metric_value < expected_lower_than
    @severities[severity] = true
    "; DatabaseConnections are #{sprintf '%d', connections_metric_value} (expected lower than #{expected_lower_than})"
  end

  def check_iops(severity, expected_lower_than)
    read_iops_metric ||= cloud_watch_metric 'ReadIOPS', 'Count/Second'
    read_iops_metric_value ||= latest_value read_iops_metric
    write_iops_metric ||= cloud_watch_metric 'WriteIOPS', 'Count/Second'
    write_iops_metric_value ||= latest_value write_iops_metric
    iops_metric_value ||= read_iops_metric_value + write_iops_metric_value
    return if iops_metric_value < expected_lower_than
    @severities[severity] = true
    "; IOPS are #{sprintf '%d', iops_metric_value} (expected lower than #{expected_lower_than})"
  end

  def run
    instances = []
    if config[:db_cluster_id]
      db_cluster_writer_id = find_db_cluster_writer(config[:db_cluster_id])
      instances << find_db_instance(db_cluster_writer_id)
    elsif config[:db_instance_id].nil? || config[:db_instance_id].empty?
      rds.describe_db_instances[:db_instances].map { |db| instances << db }
    else
      instances << find_db_instance(config[:db_instance_id])
    end

    messages = ''
    severities = {
      critical: false,
      warning:  false
    }
    instances.each do |instance|
      @db_instance = instance
      result = collect(instance)
      if result[1][:critical]
        messages += result[0]
        severities[:critical] = true
      elsif result[1][:warning]
        severities[:warning] = true
        messages += result[0]
      end
    end

    if severities[:critical]
      critical messages
    elsif severities[:warning]
      warning messages
    else
      ok messages
    end
  end

  def collect(instance)
    message = "\n#{instance[:db_instance_identifier]}: "
    @severities = {
      critical: false,
      warning:  false
    }

    @severities.each_key do |severity|
      message += check_az severity, config[:"availability_zone_#{severity}"], instance if config[:"availability_zone_#{severity}"]

      %w[cpu memory disk connections iops].each do |item|
        result = send "check_#{item}", severity, config[:"#{item}_#{severity}_over"] if config[:"#{item}_#{severity}_over"]
        message += result unless result.nil?
      end
    end

    if %w[cpu memory disk connections iops].any? { |item| %w[warning critical].any? { |severity| config[:"#{item}_#{severity}_over"] } }
      message += "(#{config[:statistics].to_s.capitalize} within #{config[:period]}s "
      message += "between #{config[:end_time] - config[:period]} to #{config[:end_time]})"
    end
    [message, @severities]
  end
end
