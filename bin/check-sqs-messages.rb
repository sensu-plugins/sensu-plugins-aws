#! /usr/bin/env ruby
#
# check-sqs-messages
#
# DESCRIPTION:
#   This plugin checks the number of messages in an Amazon Web Services SQS queue.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v2
#   gem: sensu-plugin
#
# USAGE:
#   check-sqs-messages -q my_queue -w 500 -c 1000
#   check-sqs-messages -p queue_prefix_ -W 100 -C 50
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2013, Justin Lambert <jlambert@letsevenup.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

#
# Check SQS Messages
#
class SQSMsgs < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :queues,
         short: '-q SQS_QUEUE',
         long: '--queue SQS_QUEUE',
         description: 'A comma seperated list of the SQS queue(s) you want to check the number of messages for',
         default: [],
         proc: proc { |q| q.split(',') }

  option :exclude_queues,
         short: '-Q SQS_QUEUES',
         long: '--exclude-queues SQS_QUEUE',
         description: 'A comma separated list of the SQS queue(s) to exclude, if using --prefix',
         default: [],
         proc: proc { |q| q.split(',') }

  option :prefix,
         short: '-p PREFIX',
         long: '--prefix PREFIX',
         description: 'The prefix of the queues you want to check the number of messages for',
         default: ''

  option :metric,
         short: '-m METRIC',
         long: '--metric METRIC',
         description: 'The metric of the queues you want to check the number of messages for',
         default: 'ApproximateNumberOfMessages'

  option :warn_over,
         short: '-w WARN_OVER',
         long: '--warnnum WARN_OVER',
         description: 'Number of messages in the queue considered to be a warning',
         default: -1,
         proc: proc(&:to_i)

  option :crit_over,
         short: '-c CRIT_OVER',
         long: '--critnum CRIT_OVER',
         description: 'Number of messages in the queue considered to be critical',
         default: -1,
         proc: proc(&:to_i)

  option :warn_under,
         short: '-W WARN_UNDER',
         long: '--warnunder WARN_UNDER',
         description: 'Minimum number of messages in the queue considered to be a warning',
         default: -1,
         proc: proc(&:to_i)

  option :crit_under,
         short: '-C CRIT_UNDER',
         long: '--critunder CRIT_UNDER',
         description: 'Minimum number of messages in the queue considered to be critical',
         default: -1,
         proc: proc(&:to_i)

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def run
    Aws.config.update(aws_config)
    sqs = Aws::SQS::Resource.new

    if config[:prefix].empty?
      if config[:queues].empty?
        critical 'Error, either QUEUE or PREFIX must be specified'
      end

      warnings = []
      crits = []
      passing = []
      queues = config[:queues]
      queues.each do |q|
        url = sqs.get_queue_by_name(queue_name: q).url
        messages = sqs.client.get_queue_attributes(queue_url: url, attribute_names: ['All'])
        if messages.attributes.key(config[:metric])
          messages = messages.attributes([config[:metric]]).to_i
        else
          failure_msg = <<~MESSAGE
            failed to pull metric #{config[:metric]} on queue: #{q}.
            available attributes: #{messages.attributes}
          MESSAGE
          unknown failure_msg
        end

        if (config[:crit_under] >= 0 && messages < config[:crit_under]) || (config[:crit_over] >= 0 && messages > config[:crit_over])
          crits << "#{messages} message(s) in #{q}"
        elsif (config[:warn_under] >= 0 && messages < config[:warn_under]) || (config[:warn_over] >= 0 && messages > config[:warn_over])
          warnings << "#{messages} message(s) in #{q}"
        else
          passing << "#{messages} message(s) in #{q}"
        end
      end
      if crits.any?
        critical crits.join(', ').to_s
      elsif warnings.any?
        warning warnings.join(', ').to_s
      else
        ok "all queue(s): #{queues} are OK"
      end
    else
      warn = false
      crit = false
      queues = []
      exclusions = config[:exclude_queues]

      sqs.queues(queue_name_prefix: config[:prefix]).each do |q|
        messages = sqs.client.get_queue_attributes(queue_url: q.url, attribute_names: ['All']).attributes[config[:metric]].to_i
        queue_name = q.attributes['QueueArn'].split(':').last

        next if exclusions.include? queue_name

        if (config[:crit_under] >= 0 && messages < config[:crit_under]) || (config[:crit_over] >= 0 && messages > config[:crit_over])
          crit = true
          queues << "#{messages} message(s) in #{queue_name} queue"
        elsif (config[:warn_under] >= 0 && messages < config[:warn_under]) || (config[:warn_over] >= 0 && messages > config[:warn_over])
          warn = true
          queues << "#{messages} message(s) in #{queue_name} queue"
        end
      end

      if crit
        critical queues.to_s
      elsif warn
        warning queues.to_s
      else
        ok "All queues matching prefix '#{config[:prefix]}' OK"
      end
    end
  end
end
