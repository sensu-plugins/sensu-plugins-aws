#!/usr/bin/env ruby
#
# check-elb-health-sdk
#
# DESCRIPTION:
#   This plugin checks the health of an Amazon Elastic Load Balancer or all ELBs in a given region.
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
#   check-elb-health-sdk.rb -r region
#   check-elb-health-sdk.rb -r region -n my-elb
#   check-elb-health-sdk.rb -r region -n my-elb -i instance1,instance2
#   check-alb-health-sdk.rb -r all
#
# Copyright (c) 2015, Benjamin Kett <bkett@umn.edu>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class ELBHealth < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :elb_name,
         short: '-n ELB_NAME',
         long: '--elb-name ELB_NAME',
         description: 'The Elastic Load Balancer name of which you want to check the health'

  option :instance_tag,
         short: '-t',
         long: '--instance-tag INSTANCE_TAG',
         description: "Specify instance tag to be included in the check output. E.g. 'Name' tag"

  option :instances,
         short: '-i INSTANCES',
         long: '--instances INSTANCES',
         description: 'Comma separated list of specific instances IDs inside the ELB of which you want to check the health'

  option :verbose,
         short: '-v',
         long: '--verbose',
         description: 'Enable a little bit more verbose reports about instance health',
         boolean: true,
         default: false

  option :warn_only,
         short: '-w',
         long: '--warn-only',
         description: 'Warn instead of critical when unhealthy instances are found',
         default: false

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def elb
    @elb = Aws::ElasticLoadBalancing::Client.new(aws_config)
  end

  def ec2
    @ec2 = Aws::EC2::Client.new(aws_config)
  end

  def ec2_regions
    Aws.partition('aws').regions.map(&:name)
  end

  def instances_to_check(instances)
    all_instances = instances.split(',')
    all_instances.map! { |instance| { instance_id: instance } }
  end

  def elbs
    @elbs = elb.describe_load_balancers.load_balancer_descriptions.to_a
    @elbs.select! { |elb| config[:elb_name].include? elb.load_balancer_name } if config[:elb_name]
    @elbs
  end

  def check_health(elb)
    unhealthy_instances = {}
    instance_health = if config[:instances]
                        @elb.describe_instance_health(
                          load_balancer_name: elb.load_balancer_name,
                          instances: instances_to_check(config[:instances])
                        )
                      else
                        @elb.describe_instance_health(load_balancer_name: elb.load_balancer_name)
                      end

    instance_health.instance_states.each do |instance_health_states|
      if instance_health_states.state != 'InService'
        instance_id = instance_health_states.instance_id
        state_message = instance_health_states.state

        if config[:instance_tag]
          selected_tag = ec2.describe_tags(
            filters: [{ name: 'resource-id', values: [instance_id] }]
          ).tags.select { |tag| tag[:key] == config[:instance_tag] }
          unless selected_tag.empty?
            state_message = "#{selected_tag[0][:value]}::#{instance_health_states[:state]}"
          end
        end

        unhealthy_instances[instance_id] = state_message
      end
    end
    if unhealthy_instances.empty?
      'OK'
    else
      unhealthy_instances
    end
  end

  def run
    aws_regions = ec2_regions
    @message = ''
    critical = false

    unless config[:aws_region].casecmp('all').zero?
      if aws_regions.include? config[:aws_region]
        aws_regions.clear.push(config[:aws_region])
      else
        critical 'Invalid region specified!'
      end
    end

    aws_regions.each do |r| # Iterate each possible region
      config[:aws_region] = r
      region_critical = false
      @message += (elbs.size > 1 ? config[:aws_region] + ': ' : '')
      elbs.each do |elb|
        result = check_health(elb)
        if result != 'OK'
          @message += "#{elb.load_balancer_name} unhealthy => #{result.map { |id, state| '[' + id + '::' + state + ']' }.join(' ')}. "
          critical = true
          region_critical = true
        else
          @message += "#{elb.load_balancer_name} => healthy. " unless config[:verbose] == false
        end
      end
      if elbs.size > 1 && config[:verbose] != true && region_critical == false
        @message += 'OK. '
      end
    end

    if critical
      if config[:warn_only]
        warning @message
      else
        critical @message
      end
    else
      ok @message
    end
  end
end
