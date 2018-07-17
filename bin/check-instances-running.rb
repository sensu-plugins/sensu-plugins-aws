#! /usr/bin/env ruby
#
# check-instances-running
#
#
# DESCRIPTION:
#   This plugin checks the instances running for a specific region.
#   Goal is to allow you to monitor that your region runs certain
#   number of EC2 instances
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
#     check-instances-running.rb --warn 15 --crit 25 [--tags tag_name:tag_value,tag_name:tag_value]
#
#
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2018, Juan Carlos Castillo Cano
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

# Class to check the instance count
class CheckInstancesRunning < Sensu::Plugin::Check::CLI
  include Common

  option :tags,
         description: 'Tag to use as filter',
         short: '-t TAG',
         long: '--tags TAGS',
         required: false

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as us-east-1).'

  option :warn,
         short: '-w COUNT',
         long: '--warn COUNT',
         proc: proc(&:to_i)

  option :crit,
         short: '-c COUNT',
         long: '--crit COUNT',
         proc: proc(&:to_i)

  def filters
    filter = [{ name: 'instance-state-name', values: ['running'] }]
    if config.key?(:tags)
      config[:tags].split(',').each do |tag|
        name, value = tag.split(':')
        filter << { name: "tag:#{name}", values: [value] }
      end
    end
    filter
  end

  def instance_count
    client = Aws::EC2::Client.new(region: config[:aws_region])
    resp = client.describe_instances(filters: filters).to_h
    instances = []
    resp[:reservations].each do |insts|
      insts[:instances].each do |i|
        instances << i[:instance_id]
      end
    end
    instances.length
  rescue StandardError => e
    critical "There was an error reaching AWS - #{e.message}"
  end

  def run
    count = instance_count
    msg_prefix = "#{count} instances running for region [ #{config[:aws_region]} ]"
    if count >= config[:crit]
      critical "#{msg_prefix} - critical threshold #{config[:crit]}"
    elsif count >= config[:warn]
      warning "#{msg_prefix} - warning threshold #{config[:warn]}, critical threshold #{config[:crit]}"
    else
      ok msg_prefix
    end
  end
end
