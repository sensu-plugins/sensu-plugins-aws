#! /usr/bin/env ruby
#
# check-dynamodb-throttle
#
# DESCRIPTION:
#   Check DynamoDB throttle by CloudWatch and DynamoDB API.
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
#   Critical if session table's read throttle is over 50 for the last 5 minutes
#   check-dynamodb-throttle --table_names session --throttle-for read --critical-over 50 --statistics sum --period 300
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'time'

class CheckDynamoDB < Sensu::Plugin::Check::CLI
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

  option :table_names,
         short:       '-t N',
         long:        '--table-names NAMES',
         proc:        proc { |a| a.split(/[,;]\s*/) },
         description: 'Table names to check. Separated by , or ;. If not specified, check all tables'

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

  option :throttle_for,
         short:       '-c N',
         long:        '--throttle-for NAME',
         default:     %i[read write],
         proc:        proc { |a| a.split(/[,;]\s*/).map { |n| n.downcase.intern } },
         description: 'Read/Write (or both) throttle to check.'

  %w[warning critical].each do |severity|
    option :"#{severity}_over",
           long:        "--#{severity}-over N",
           proc:        proc(&:to_f),
           description: "Trigger a #{severity} if throttle is over the given number"
  end

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def dynamo_db
    @dynamo_db ||= Aws::DynamoDB::Client.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= Aws::CloudWatch::Client.new aws_config
  end

  def tables
    return @tables if @tables
    table_names = dynamo_db.list_tables.table_names.to_a
    table_names.select! { |table_name| config[:table_names].include? table_name } if config[:table_names]
    @tables = []
    table_names.each do |table_name|
      @tables.push(dynamo_db.describe_table(
        table_name: table_name
      ).table)
    end
    @tables
  end

  def cloud_watch_metric(metric_name, table_name)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/DynamoDB',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'TableName',
          value: table_name
        }
      ],
      start_time: config[:end_time] - config[:period],
      end_time: config[:end_time],
      statistics: [config[:statistics].to_s.capitalize],
      period: config[:period],
      unit: 'Count'
    )
  end

  def latest_value(metric)
    metric.datapoints.sort_by { |datapoint| datapoint[:timestamp] }.last[config[:statistics]]
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def check_throttle(table)
    config[:throttle_for].each do |r_or_w|
      metric_name   = "#{r_or_w.to_s.capitalize}ThrottleEvents"
      metric        = cloud_watch_metric metric_name, table.table_name
      metric_value  = begin
                        latest_value(metric)
                      rescue StandardError
                        0
                      end

      @severities.each_key do |severity|
        threshold = config[:"#{severity}_over"]
        next unless threshold
        next if metric_value < threshold
        flag_alert severity, "; On table #{table.table_name} #{r_or_w.to_s.capitalize}ThrottleEvents is #{metric_value} (higher_than #{threshold})"
        break
      end
    end
  end

  def run
    @message    = "#{tables.size} tables total"
    @severities = {
      critical: false,
      warning: false
    }

    tables.each { |table| check_throttle table }

    @message += "; (#{config[:statistics].to_s.capitalize} within #{config[:period]} seconds "
    @message += "between #{config[:end_time] - config[:period]} to #{config[:end_time]})"

    if @severities[:critical]
      critical @message
    elsif @severities[:warning]
      warning @message
    else
      ok @message
    end
  end
end
