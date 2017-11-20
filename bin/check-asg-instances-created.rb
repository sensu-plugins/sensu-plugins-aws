#! /usr/bin/env ruby
#
# check-asg-instance-created
#
# DESCRIPTION:
#   Check AutoScalingGroup Instances are Terminated & Launching last hour.
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
#   all AutoScalingGroup
#   ./check-asg-instance-created -r ${your_region}
#   one AutoScalingGroup
#   ./check-asg-instance-created -r ${your_region} -g 'AutoScalingGroupName'
#
# NOTES:
#   Based heavily on Peter Hoppe check-asg-instance-created
#
# LICENSE:
#   Peter Hoppe <peter.hoppe.extern@bertelsmann.de>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class CheckAsgInstanceCreated < Sensu::Plugin::Check::CLI
  include Common
  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     ENV['AWS_REGION']

  option :asg_group_name,
         short:       '-g G',
         long:        '--asg_group_name AutoScalingGroupName',
         description: 'AutoScalingGroupName to check'

  option :warning_limit,
         short:       '-w W',
         long:        '--warning_limit Warning Limit',
         description: 'Warning Limit for launching and terminated instances',
         proc: proc(&:to_i)

  option :critical_limit,
         short:       '-c C',
         long:        '--critical_limit Critical Limit',
         description: 'Critical Limit for launching and terminated instances',
         proc: proc(&:to_i)

  def asg
    @asg = Aws::AutoScaling::Client.new
  end

  def describe_activities(asg_group_name)
    asg.describe_scaling_activities(
      auto_scaling_group_name: asg_group_name.to_s
    )
  end

  def run
    warning = 3
    critical = 4
    result_launched = ''
    result_terminated = ''
    instance_launching = 0
    instance_terminating = 0
    time_now = Time.now
    time_utc_offset = time_now - time_now.utc_offset

    if !config[:warning_limit].nil?
      warning = config[:warning_limit]
    elsif !config[:critical_limit].nil?
      critical = config[:critical_limit]
    end

    if config[:asg_group_name].nil?
      asg.describe_auto_scaling_groups.auto_scaling_groups.each do |asg_group|
        describe_activities(asg_group.auto_scaling_group_name).each do |activities|
          activities.activities.each do |activity|
            if Time.parse(activity.start_time.inspect) > (time_utc_offset - 3600)
              if activity.description.include? 'Launching'
                instance_launching += 1
                result_launched = " #{instance_launching} Instances Launching in AutoScalingGroup #{asg_group.auto_scaling_group_name}"
              elsif activity.description.include? 'Terminating'
                instance_terminating += 1
                result_terminated = " #{instance_terminating} Instances Terminated in AutoScalingGroup #{asg_group.auto_scaling_group_name}"
              end
            end
          end
        end
      end
    else
      describe_activities(config[:asg_group_name]).each do |activities|
        activities.activities.each do |activity|
          if Time.parse(activity.start_time.inspect) > (time_utc_offset - 3600)
            if activity.description.include? 'Launching'
              instance_launching += 1
              result_launched = " #{instance_launching} Instances Launching in AutoScalingGroup #{config[:asg_group_name]}"
            elsif activity.description.include? 'Terminating'
              instance_terminating += 1
              result_terminated = " #{instance_terminating} Instances Terminated in AutoScalingGroup #{config[:asg_group_name]}"
            end
          end
        end
      end
    end
    if instance_terminating.zero? && instance_launching.zero?
      ok 'No instances Launched & Terminated last hour'
    elsif instance_terminating >= critical && instance_launching >= critical
      critical "#{result_launched} \n #{result_terminated}"
    elsif instance_terminating >= warning && instance_launching >= warning
      warning "#{result_launched} \n #{result_terminated}"
    else
      ok "#{result_launched} \n #{result_terminated}"
    end
  end
end
