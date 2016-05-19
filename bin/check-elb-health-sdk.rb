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
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   check-elb-health-sdk.rb -r region
#   check-elb-health-sdk.rb -r region -n my-elb
#   check-elb-health-sdk.rb -r region -n my-elb -i instance1,instance2
#
# Copyright (c) 2015, Benjamin Kett <bkett@umn.edu>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

class ELBHealth < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

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
    @elb = AWS::ELB.new aws_config
  end

  def ec2
    @ec2 = AWS::EC2::Client.new aws_config
  end

  def ec2_regions
    # This is for SDK v2
    # Aws.partition('aws').regions.map(&:name)

    AWS::EC2.regions.map(&:name)
  end

  def elbs
    @elbs = elb.load_balancers.to_a
    @elbs.select! { |elb| config[:elb_name].include? elb.name } if config[:elb_name]
    @elbs
  end

  def check_health(elb)
    unhealthy_instances = {}
    instance_health_hash = if config[:instances]
                             elb.instances.health(config[:instances])
                           else
                             elb.instances.health
                           end
    instance_health_hash.each do |instance_health|
      if instance_health[:state] != 'InService'
        instance_id = instance_health[:instance].id
        state_message = instance_health[:state]

        if config[:instance_tag]
          instance = ec2.describe_instances(instance_ids: [instance_id])
          selected_tag = instance[:reservation_index][instance_id][:instances_set][0][:tag_set].select { |tag| tag[:key] == config[:instance_tag] }
          unless selected_tag.empty?
            state_message = "#{selected_tag[0][:value]}::#{instance_health[:state]}"
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

    unless config[:aws_region].casecmp('all') == 0
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
        result = check_health elb
        if result != 'OK'
          @message += "#{elb.name} unhealthy => #{result.map { |id, state| '[' + id + '::' + state + ']' }.join(' ')}. "
          critical = true
          region_critical = true
        else
          @message += "#{elb.name} => healthy. " unless config[:verbose] == false
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
