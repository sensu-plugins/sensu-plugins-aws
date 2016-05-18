#! /usr/bin/env ruby
#
# check-autoscaling-cpucredits
#
# DESCRIPTION:
#   Check AutoScaling CPU Credits through CloudWatch API.
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
#   ./check-autoscaling-cpucredits.rb -r ${your_region} --warning-under 100 --critical-under 50
#
# NOTES:
#   Based heavily on Yohei Kawahara's check-ec2-network
#
# LICENSE:
#   Gavin Hamill <gavin@bashton.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckEc2CpuCredits < Sensu::Plugin::Check::CLI
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

  option :group,
         short:       '-g G',
         long:        '--autoscaling-group GROUP',
         description: 'AutoScaling group to check'

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     60,
         description: 'CloudWatch metric statistics period'

  option :countmetric,
         short:       '-d M',
         long:        '--countmetric METRIC',
         default:     'CPUCreditBalance',
         description: 'Select any CloudWatch _Count_ based metric (Status Checks / CPU Credits)'

  option :warning_under,
         short:       '-w N',
         long:        '--warning-under VALUE',
         description: 'Issue a warning if the CloudWatch _Count_ based metric (Status Check / CPU Credits) is below this value'

  option :critical_under,
         short:       '-c N',
         long:        '--critical-under VALUE',
         description: 'Issue a critical if the CloudWatch _Count_ based metric (Status Check / CPU Credits) is below this value'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def asg
    @asg ||= Aws::AutoScaling::Client.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= Aws::CloudWatch::Client.new aws_config
  end

  def get_count_metric(group)
    cloud_watch.get_metric_statistics(
      namespace: 'AWS/EC2',
      metric_name: config[:countmetric].to_s,
      dimensions: [
        {
          name: 'AutoScalingGroupName',
          value: group
        }
      ],
      start_time: config[:end_time] - 600,
      end_time: config[:end_time],
      statistics: ['Average'],
      period: config[:period],
      unit: 'Count'
    )
  end

  def latest_value(value)
    value.datapoints[0][:average].to_f unless value.datapoints[0].nil?
  end

  def check_metric(group)
    metric = get_count_metric group
    latest_value metric unless metric.nil?
  end

  def check_group(group, reportstring, warnflag, critflag)
    metric_value = check_metric group
    if !metric_value.nil? && metric_value < config[:critical_under].to_f
      critflag = 1
      reportstring = reportstring + group + ': ' + metric_value.to_s + ' '
    elsif !metric_value.nil? && metric_value < config[:warning_under].to_f
      warnflag = 1
      reportstring = reportstring + group + ': ' + metric_value.to_s + ' '
    end
    [reportstring, warnflag, critflag]
  end

  def run
    warnflag = 0
    critflag = 0
    reportstring = ''
    if config[:group].nil?
      asg.describe_auto_scaling_groups.auto_scaling_groups.each do |group|
        if group.desired_capacity > 0
          reportstring, warnflag, critflag = check_group(group.auto_scaling_group_name, reportstring, warnflag, critflag)
        end
      end
    else
      reportstring, warnflag, critflag = check_group(config[:group], reportstring, warnflag, critflag)
    end

    if critflag == 1
      critical reportstring
    elsif warnflag == 1
      warning reportstring
    else
      ok 'All checked AutoScaling Groups are cool'
    end
  end
end
