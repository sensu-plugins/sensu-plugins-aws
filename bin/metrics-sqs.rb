#! /usr/bin/env ruby
#
# metrics-sqs
#
# DESCRIPTION:
#   Fetch SQS metrics
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   metrics-sqs -q my_queue
#   metrics-sqs -p queue_prefix_
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class SQSMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :queue,
         description: 'Name of the queue',
         short: '-q QUEUE',
         long: '--queue QUEUE',
         default: ''

  option :prefix,
         description: 'Queue name prefix',
         short: '-p PREFIX',
         long: '--prefix PREFIX',
         default: ''

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

  option :aws_region,
         description: 'AWS Region (defaults to us-east-1).',
         short: '-r AWS_REGION',
         long: '--aws-region AWS_REGION',
         default: 'us-east-1'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def scheme(queue_name)
    scheme = config[:scheme].empty? ? 'aws.sqs.queue' : config[:scheme]
    "#{scheme}.#{queue_name.tr('-', '_')}.message_count"
  end

  def record_queue_metrics(q_name, q)
    output scheme(q_name), q.attributes['ApproximateNumberOfMessages'].to_i
    output "#{scheme(q_name)}.delayed", q.attributes['ApproximateNumberOfMessagesDelayed'].to_i
    output "#{scheme(q_name)}.not_visible", q.attributes['ApproximateNumberOfMessagesNotVisible'].to_i
  end

  def run
    begin
      sqs = Aws::SQS::Resource.new(aws_config)

      if config[:prefix] == ''
        if config[:queue] == ''
          critical 'Error, either QUEUE or PREFIX must be specified'
        end

        record_queue_metrics(config[:queue], sqs.get_queue_by_name(queue_name: config[:queue]))
      else
        sqs.queues(queue_name_prefix: config[:prefix]).each do |q|
          record_queue_metrics(q.attributes['QueueArn'].split(':').last, q)
        end
      end
    rescue StandardError => e
      critical "Error fetching SQS queue metrics: #{e.message}"
    end
    ok
  end
end
