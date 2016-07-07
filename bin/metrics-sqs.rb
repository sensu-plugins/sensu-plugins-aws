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
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   metrics-sqs -q my_queue -a key -k secret
#   metrics-sqs -p queue_prefix_ -a key -k secret
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk-v1'

class SQSMetrics < Sensu::Plugin::Metric::CLI::Graphite
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

  option :aws_access_key,
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         default: ENV['AWS_SECRET_KEY']

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
    output scheme(q_name), q.approximate_number_of_messages
    output "#{scheme(q_name)}.delayed", q.approximate_number_of_messages_delayed
    output "#{scheme(q_name)}.not_visible", q.approximate_number_of_messages_not_visible
  end

  def run
    begin
      sqs = AWS::SQS.new aws_config

      if config[:prefix] == ''
        if config[:queue] == ''
          critical 'Error, either QUEUE or PREFIX must be specified'
        end

        record_queue_metrics(config[:queue], sqs.queues.named(config[:queue]))
      else
        sqs.queues.with_prefix(config[:prefix]).each do |q|
          record_queue_metrics(q.arn.split(':').last, q)
        end
      end
    rescue => e
      critical "Error fetching SQS queue metrics: #{e.message}"
    end
    ok
  end
end
