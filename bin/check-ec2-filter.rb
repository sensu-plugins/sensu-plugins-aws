#! /usr/bin/env ruby
#
# check-ec2-filter
#
# DESCRIPTION:
#   This plugin retrieves EC2 instances matching a given filter and
#   returns the number matched. Warning and Critical thresholds may be set as needed.
#   Thresholds may be compared to the count using [equal, not, greater, less] operators.
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
#   ./check-ec2-filter.rb -w 20 -f "{name:tag-value,values:[infrastructure]}"
#   ./check-ec2-filter.rb -w 10 -c 5 -o less -f "{name:tag-value,values:[infrastructure]} {name:instance-state-name,values:[running]}"
#
# NOTES:
#
# LICENSE:
#   Justin McCarty
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws/filter'

class EC2Filter < Sensu::Plugin::Check::CLI
  include Filter
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

  option :name,
         description: 'Filter naming scheme, text to prepend to metric',
         short: '-n NAME',
         long: '--name NAME',
         default: ''

  option :filter,
         short: '-f FILTER',
         long: '--filter FILTER',
         description: 'String representation of the filter to apply',
         default: '{}'

  option :warning,
         description: 'Warning threshold for filter',
         short: '-w COUNT',
         long: '--warning COUNT'

  option :critical,
         description: 'Critical threshold for filter',
         short: '-c COUNT',
         long: '--critical COUNT'

  option :exclude_tags,
         short: '-e {<tag-key>:[VAL1, VAL2]} {<tag-key>:[VAL1, VAL2] }',
         long: '--exclude_tags {<tag-key>:[VAL1, VAL2] } {<tag-key>:[VAL1, VAL2] }',
         description: 'Tag Values to exclude by. Values treated as regex. Any matching value will result in exclusion.',
         default: '{}'

  option :compare,
         description: 'Comparision operator for threshold: equal, not, greater, less',
         short: '-o OPERATION',
         long: '--operator OPERATION',
         default: 'equal'

  option :detailed_message,
         short: '-d',
         long: '--detailed-message',
         boolean: true,
         default: false

  option :min_running_secs,
         long: '--min-running-secs SECONDS',
         default: nil

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def convert_operator
    op = ->(c, t) { c == t }

    if config[:compare] == 'greater'
      op = ->(c, t) { c > t }
    elsif config[:compare] == 'less'
      op = ->(c, t) { c < t }
    elsif config[:compare] == 'not'
      op = ->(c, t) { c != t }
    end

    op
  end

  def run
    filter_list = config[:exclude_tags].split(/}\s?{/).map do |x|
      x.gsub(/[{}]/, '')
    end
    filter_list = filter_list.map do |y|
      _, h2, h3 = y.split(/(.*):(.*)/)
      { h2 => h3 }
    end.reduce(:merge)
    filter_list.delete(nil)
    filter_list.each { |x, y| filter_list[x] = y.strip.gsub(/[\[\]]/, '') }

    client = Aws::EC2::Client.new aws_config

    filter = Filter.parse(config[:filter])

    options = if filter.empty?
                {}
              else
                { filters: filter }
              end

    data = client.describe_instances(options)

    aws_instances = Set.new
    data.reservations.each do |r|
      r.instances.each do |i|
        aws_instances << {
          id: i[:instance_id],
          launch_time: i.launch_time,
          tags: i.tags
        }
      end
    end

    aws_instances.delete_if do |instance|
      instance[:tags].any? do |key|
        filter_list.keys.include?(key.key) && filter_list[key.key].split(',').any? do |v|
          key.value.match(/#{v.strip}/)
        end
      end
    end

    unless config[:min_running_secs].nil?
      aws_instances.delete_if do |instance|
        (Time.now.utc - instance[:launch_time]).to_i < config[:min_running_secs].to_i
      end
    end

    count = aws_instances.count
    op = convert_operator
    message = "Current count: #{count}"
    message += " - #{aws_instances.collect { |x| x[:id] }.join(',')}" if config[:detailed_message] && count > 0

    unless config[:critical].nil?
      if op.call count, config[:critical].to_i
        critical message
      end
    end

    unless config[:warning].nil?
      if op.call count, config[:warning].to_i
        warning message
      end
    end

    ok message
  rescue StandardError => e
    puts "Error: exception: #{e}"
    critical
  end
end
