#!/usr/bin/env ruby
#
# check-efs-metric
#
# DESCRIPTION:
#   This plugin checks a CloudWatch metric from the AWS/EFS namespace
#   For more details, see https://docs.aws.amazon.com/efs/latest/ug/monitoring-cloudwatch.html#efs-metrics
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
#   ./check-efs-metric -w 25.0 -c 75.0 \
#   -m PercentIOLimit -o greater -n my-efs-filesystem-name
#
# NOTES:
#
# LICENSE:
#   Ivan Fetch
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

# A Sensu plugin which uses cloudwatch-common to  check EFS CloudWatch metrics
class EFSMetric < Sensu::Plugin::Check::CLI
  include Common
  include CloudwatchCommon

  option :efs_name,
         description: 'Name of the EFS file system, matching the Name tag',
         short: '-n VALUE',
         long: '--name VALUE',
         proc: proc(&:to_s),
         required: true

  option :metric_name,
         description: 'CloudWatch metric in the AWS/EFS namespace: E.G. PercentIOLimit',
         short: '-m VALUE',
         long: '--metric VALUE',
         proc: proc(&:to_s),
         required: true

  option :statistics,
         description: 'Statistic to retrieve from CloudWatch: E.G. Minimum or Maximum',
         short: '-s statistic',
         long: '--statistic statistic',
         default: 'Average',
         proc: proc(&:to_s)

  option :critical,
         description: 'Return critical when the metric is at this VALUE, also see the --operator option',
         short: '-c VALUE',
         long: '--critical VALUE',
         proc: proc(&:to_f),
         required: true

  option :warning,
         description: 'Return warning when the metric is at this VALUE, also see the --operator option',
         short: '-w VALUE',
         long: '--warning VALUE',
         proc: proc(&:to_f)

  option :period,
         description: 'CloudWatch metric statistics period, in seconds. Must be a multiple   of 60',
         short: '-p VALUE',
         long: '--period VALUE',
         default: 60,
         proc: proc(&:to_i)

  option :compare,
         description: 'Comparison operator for critical and warning thresholds: equal, not, greater, less',
         short: '-o OPERATOR',
         long: '--operator OPERATOR',
         default: 'less'

  option :unit,
         description: 'CloudWatch metric unit, to be passed to the metrics request',
         short: '-u UNIT',
         long: '--unit UNIT'

  option :no_data_ok,
         description: 'Returns ok if no data is returned from the metric',
         short: '-O',
         long: '--allow-no-data',
         boolean: true,
         default: false

  option :no_efs_ok,
         description: 'Returns ok if the EFS file system specified by the -n option can not be found: This is useful if using a check in multiple environments where a file system may not always exist',
         short: '-N',
         long: '--allow-no-efs',
         boolean: true,
         default: false

  option :aws_region,
         description: 'AWS region',
         short: '-r Region',
         long: '--region REGION',
         default: 'us-east-1'

  # This is used by CloudwatchCommon to display the description for what is being checked.
  def metric_desc
    "#{config[:metric_name]} for #{config[:efs_name]}"
  end

  def run
    config[:namespace] = 'AWS/EFS'
    found_efs = false

    efs = Aws::EFS::Client.new
    filesystems = efs.describe_file_systems
    filesystems.file_systems.each do |filesystem|
      # Once Ruby < ver 2.4 is not supported, change this to:
      # if filesystem.name.casecmp?(config[:efs_name])
      # See : https://ruby-doc.org/core-2.4.0/String.html#method-i-casecmp
      if filesystem.name.casecmp(config[:efs_name]).zero?
        found_efs = true
        config[:dimensions] = []
        config[:dimensions] << { name: 'FileSystemId', value: filesystem.file_system_id }
        check config
      end
    end

    # rubocop:disable Style/GuardClause
    unless found_efs
      if config[:no_efs_ok]
        ok "EFS file system #{config[:efs_name]} was not found in region #{config[:aws_region]} but that's ok"
      else
        critical "EFS file system #{config[:efs_name]} was not found in region #{config[:aws_region]}"
      end
    end
    # rubocop:enable Style/GuardClause
  end
end
