#! /usr/bin/env ruby
#
# check-asg-instance-terminated
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
#   ./check-asg-instance-terminated -r ${your_region}
#   one AutoScalingGroup
#   ./check-asg-instance-terminated -r ${your_region} -g 'AutoScalingGroupName'
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

class CheckAsgInstancesCreated < Sensu::Plugin::Check::CLI
  include Common
  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     ENV['AWS_REGION']

  option :asgname,
         description: 'Name of the Auto Scaling Group',
         short: '-n ASG_NAME',
         long: '--name ASG_NAME'

  option :warning_limit,
         short:       '-w W',
         long:        '--warning_limit Warning Limit',
         description: 'Warning Limit for launching and terminated instances'

  option :critical_limit,
         short:       '-c C',
         long:        '--critical_limit Critical Limit',
         description: 'Critical Limit for launching and terminated instances'

  option :time_limit,
         short:       '-t T',
         long:        '--time Timelimit',
         description: 'Time Limit for launching and terminated instances (default 1800s)'

  def asg
    @asg = Aws::AutoScaling::Client.new
  end

  def ec2
    @ec2 = Aws::EC2::Client.new
  end

  def describe_activities(asg_group_name)
    asg.describe_scaling_activities(
      auto_scaling_group_name: asg_group_name.to_s
    )
  end

  def describe_instance(instance_id)
    ec2.describe_instances(
      instance_ids: [instance_id]
    )
  end

  def run
    warning = 2
    critical = 3
    time = 1800
    result_terminated = ''
    instance_terminating = 0
    time_now = Time.now
    time_utc_offset = time_now - time_now.utc_offset

    instance_id_regex = Regexp.new(/.*: ([a-z0-9-]+)$/)

    if !config[:warning_limit].nil?
      warning = config[:warning_limit]
    end
    if !config[:critical_limit].nil?
      critical = config[:critical_limit]
    end
    if !config[:time_limit].nil?
      time = config[:time_limit]
    end

    if config[:asg_group_name].nil?
      asg.describe_auto_scaling_groups.auto_scaling_groups.each do |asg_group|
        describe_activities(asg_group.auto_scaling_group_name).each do |activities|
          activities.activities.each do |activity|
            if Time.parse(activity.start_time.inspect) > (time_utc_offset - time)
              if activity.description.include? 'Terminating'
                id = activity.description.gsub!(/^.*: ([a-z0-9-]+)$/,'\1')
                if Time.parse(describe_instance(id).reservations[0].instances[0].launch_time.inspect) > (time_utc_offset - time)
                  instance_terminating += 1
                  result_terminated = " #{instance_terminating} Instances Terminated in AutoScalingGroup #{asg_group.auto_scaling_group_name}"
                end
              end
            end
          end
        end
      end
    else
      describe_activities(config[:asg_group_name]).each do |activities|
        activities.activities.each do |activity|
          if Time.parse(activity.start_time.inspect) > (time_utc_offset - time)
            if activity.description.include? 'Terminating'
              id = activity.description.gsub!(/^.*: ([a-z0-9-]+)$/,'\1')
              if Time.parse(describe_instance(id).reservations[0].instances[0].launch_time.inspect) > (time_utc_offset - time)
                  instance_terminating += 1
                  result_terminated = " #{instance_terminating} Instances Terminated in AutoScalingGroup #{config[:asg_group_name]}"
              end
            end
          end
        end
      end
    end

    if instance_terminating == 0
      ok 'No instances Launched & Terminated last hour'
    elsif instance_terminating >= critical
      critical "#{result_terminated}"
    elsif instance_terminating >= warning
      warning "#{result_terminated}"
    else
      ok "#{result_terminated}"
    end
  end
end
