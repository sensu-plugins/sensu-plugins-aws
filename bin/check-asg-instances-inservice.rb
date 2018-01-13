#! /usr/bin/env ruby
#
# check-autoscaling-instances-inservice
#
# DESCRIPTION:
#   Check AutoScaling Instances inService.
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
#   ./check-autoscaling-instances-inservices.rb -r ${your_region}
#   one autoScalingGroup
#   ./check-autoscaling-instances-inservices.rb -r ${your_region} -g 'autoScalingGroupName'
#
# NOTES:
#   Based heavily on Yohei Kawahara's check-ec2-network
#
# LICENSE:
#   Peter Hoppe <peter.hoppe.extern@bertelsmann.de>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckAsgInstancesInService < Sensu::Plugin::Check::CLI
  include Common
  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     ENV['AWS_REGION']

  option :group,
         short:       '-g G',
         long:        '--autoscaling-group GROUP',
         description: 'AutoScaling group to check'

  def asg
    @asg ||= Aws::AutoScaling::Client.new
  end

  def describe_asg(asg_name)
    asg.describe_auto_scaling_groups(
      auto_scaling_group_names: [asg_name.to_s]
    )
  end

  def run
    warning = 0
    critical = 0
    instance_in_service = 0
    result = ''
    if config[:group].nil?
      asg.describe_auto_scaling_groups.auto_scaling_groups.each do |group|
        grp_name = group.auto_scaling_group_name
        instance_in_service = 0
        group.instances.each do |instance|
          if instance.lifecycle_state == 'InService'
            instance_in_service += 1
          end
        end
        if instance_in_service.zero?
          critical = 1
          result += "#{grp_name}: no Instances inService  #{instance_in_service} \n"
        elsif instance_in_service < group.min_size
          warning = 1
          result += "#{grp_name} Intance are not okay #{instance_in_service} \n"
        else
          result += "#{grp_name} Intance are inService #{instance_in_service} \n"
        end
      end
    else
      selected_group = describe_asg(config[:group])[0][0]
      min_size = selected_group.min_size
      selected_group.instances.each do |instance|
        if instance.lifecycle_state == 'InService'
          instance_in_service += 1
        end
      end
      if instance_in_service.zero?
        critical = 1
        result += "#{config[:group]}: no Instances inService  #{instance_in_service} \n"
      elsif instance_in_service < min_size
        warning = 1
        result += "#{config[:group]} Intance are not okay #{instance_in_service} \n"
      else
        result += "#{config[:group]} Intance are inService #{instance_in_service} \n"
      end
    end
    if critical == 1
      critical result
    elsif warning == 1
      warning result
    else
      ok result
    end
  end
end
