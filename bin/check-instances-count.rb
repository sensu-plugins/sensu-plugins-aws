#! /usr/bin/env ruby
#
# check-instances-count
#
#
# DESCRIPTION:
#   This plugin checks the instances count for a specific auto scale group ( ASG ).
#   Goal is to allow you to monitor that your ASG isnt out of control
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
#   #Using IAM Profile
#     check-instances-count.rb --warn 15 --crit 25 --groupname logstash-instances-auto --use-iam
#
#
#   #Using credentials
#     check-instances-count.rb --warn 15 --crit 25 --groupname logstash-instances-auto \
#     --aws-access-key AWS_ACCESS_KEY --aws-secret-access-key AWS_SECRET_ACCESS_KEY
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Kevin Bond
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

# Class to check the instance count
class CheckInstanceCount < Sensu::Plugin::Check::CLI
  option :groupname,
         description: 'Name of the AutoScaling group',
         short: '-g GROUP_NAME',
         long: '--groupname GROUP_NAME',
         required: true

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY_ID']

  option :use_iam_role,
         short: '-u',
         long: '--use-iam',
         description: 'Use IAM role authenticiation. Instance must have IAM role assigned for this to work'

  option :aws_secret_access_key,
         short: '-s AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_ACCESS_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as us-east-1).',
         default: 'us-east-1'

  option :warn,
         short: '-w COUNT',
         long: '--warn COUNT',
         proc: proc(&:to_i),
         default: 15

  option :crit,
         short: '-c COUNT',
         long: '--crit COUNT',
         proc: proc(&:to_i),
         default: 25

  attr_reader :aws_config, :aws_connection

  def initialize
    super
    @aws_config = aws_login
    @aws_connection = AWS::AutoScaling.new(@aws_config.merge!(region: config[:aws_region]))
  end

  def aws_config
    hash = {}
    hash.update access_key_id: config[:aws_access_key], secret_access_key: config[:aws_secret_access_key]\
      if config[:aws_access_key] && config[:aws_secret_access_key]
    hash.update region: config[:aws_region]
    hash
  end

  def aws_login
    aws_config =   {}

    if config[:use_iam_role].nil?
      aws_config.merge!(
        access_key_id: config[:aws_access_key],
        secret_access_key: config[:aws_secret_access_key]
      )
    end
    aws_config
  end
  # rubocop:disable Style/RedundantBegin
  def instance_count
    begin
      @aws_connection.groups[config[:groupname]].auto_scaling_instances.map(&:lifecycle_state).count('InService').to_i
    rescue => e
      critical "There was an error reaching AWS - #{e.message}"
    end
  end

  # rubocop:disable Metrics/AbcSize
  def run
    count = instance_count
    msg_prefix = "#{count} instances running for ASG [ #{config[:groupname]} ]"
    case
    when count >= config[:crit]
      critical "#{msg_prefix} - critical threshold #{config[:crit]}"
    when count >= config[:warn]
      warning "#{msg_prefix} - warning threshold #{config[:warn]}, critical threshold #{config[:crit]}"
    else
      ok "#{msg_prefix}"
    end
  end
end

