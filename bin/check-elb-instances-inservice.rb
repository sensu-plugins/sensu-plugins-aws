#! /usr/bin/env ruby
#
# check-elb-instance-inservice
#
# DESCRIPTION:
#   Check Elastic Loudbalancer Instances are inService.
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
#   all LoadBalancers
#   ./check-elb-instance-inservice -r ${your_region}
#   one loadBalancer
#   ./check-elb-instance-inservice -r ${your_region} -l 'LoadBalancerName'
#
# NOTES:
#   Based heavily on Peter Hoppe check-autoscaling-instances-inservices
#
# LICENSE:
#   Peter Hoppe <peter.hoppe.extern@bertelsmann.de>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class CheckElbInstanceInService < Sensu::Plugin::Check::CLI
  include Common
  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     ENV['AWS_REGION']

  option :load_balancer,
         short:       '-l L',
         long:        '--load_balancer LoudBalancer',
         description: 'LoadBalancer Name to check'

  def elb
    @elb ||= Aws::ElasticLoadBalancing::Client.new
  end

  def describe_elb(elb_name)
    elb.describe_instance_health(
      load_balancer_name: elb_name.to_s
    )
  end

  def run
    warning = 0
    critical = 0
    result = ''
    if config[:load_balancer].nil?
      elb.describe_load_balancers.load_balancer_descriptions.each do |load_balancer|
        describe_elb(load_balancer.load_balancer_name).each do |instances|
          instances.instance_states.each do |instance|
            if instance.state == 'InService'
              result += "#{instance.instance_id} state InService "
            else
              result += "#{instance.instance_id} state not InService "
              warning += 1
            end
          end
          if warning == instances.instance_states.length
            critical = 1
          end
        end
      end
    else
      describe_elb(config[:load_balancer]).each do |instances|
        instances.instance_states.each do |instance|
          if instance.state == 'InService'
            result += "#{instance.instance_id} state InService "
          else
            result += "#{instance.instance_id} state not InService "
            warning += 1
          end
        end
        if warning == instances.instance_states.length
          critical = 1
        end
      end
    end
    if critical == 1
      critical result
    elsif warning >= 1
      warning result
    else
      ok result
    end
  end
end
