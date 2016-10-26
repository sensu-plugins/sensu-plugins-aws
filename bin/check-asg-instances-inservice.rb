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

class CheckAsgInstancesInService < Sensu::Plugin::Check::CLI
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


  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def asg
    @asg ||= Aws::AutoScaling::Client.new aws_config
  end
 
  def run 
    warning = 0
    critical = 0
    result = ""  
    asg.describe_auto_scaling_groups.auto_scaling_groups.each do |group|
      grp_name = group.auto_scaling_group_name 
      instance_in_service = 0
      group.instances.each do |instance| 
        if instance.lifecycle_state == 'InService'
          instance_in_service = instance_in_service + 1
        end
      end
      if instance_in_service == 0
        critical = 1
        result = result + "#{grp_name}: no Instances inService  #{instance_in_service} \n"
      elsif instance_in_service < group.min_size
        warning = 1
        result = result + "#{grp_name} Intance are not okay #{instance_in_service} \n"
      else
        result = result + "#{grp_name} Intance are inService #{instance_in_service} \n"
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

