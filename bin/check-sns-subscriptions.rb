#! /usr/bin/env ruby
#
# check-sns-subscriptions
#
# DESCRIPTION:
#   This plugin checks if topics's subscriptions are not 'PendingConfirmation' state.
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
#   ./check-sns-subscriptions.rb --aws-region eu-west-1
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2016, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckSNSSubscriptions < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  def run
    sns = Aws::SNS::Client.new

    subscriptions = sns.list_subscriptions.subscriptions

    pending_confirmations = subscriptions.select { |subscription| subscription.subscription_arn == 'PendingConfirmation' }.map(&:topic_arn)

    critical "#{pending_confirmations.size} pending confirmations (#{pending_confirmations})" unless pending_confirmations.empty?
    ok
  end
end
