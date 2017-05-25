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
#   gem: sensu-plugin
#   gem: aws-sdk
#
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
require 'sensu-plugins-aws'
require 'aws-sdk'

class SQSMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :queue,
         description: 'Name of the queue',
         short: '-q QUEUE',
         long: '--queue QUEUE',
         default: false

  option :prefix,
         description: 'Queue name prefix',
         short: '-p PREFIX',
         long: '--prefix PREFIX',
         default: false

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

  def record_queue_metrics(q_name, attributes)
    output scheme(q_name), attributes['ApproximateNumberOfMessages']
    output "#{scheme(q_name)}.delayed", attributes['ApproximateNumberOfMessagesDelayed']
    output "#{scheme(q_name)}.not_visible", attributes['ApproximateNumberOfMessagesNotVisible']
  end

  def run
    begin
      sqs = Aws::SQS::Client.new(aws_config)

      if config[:queue]
        url = sqs.get_queue_url(queue_name: config[:queue]).queue_url
        record_queue_metrics(config[:queue], sqs.get_queue_attributes(queue_url: url, attribute_names: ['All']).attributes)
      else
        prefix = config[:prefix] ? { queue_name_prefix: config[:prefix] } : {}
        sqs.list_queues(prefix).queue_urls.each do |u|
          record_queue_metrics(u.split('/').last, sqs.get_queue_attributes(queue_url: u, attribute_names: ['All']).attributes)
        end
      end
    rescue => e
      critical "Error fetching SQS queue metrics: #{e.message}"
    end
    ok
  end
end
