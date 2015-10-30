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

  option :compare,
         description: 'Comparision operator for threshold: equal, not, greater, less',
         short: '-o OPERATION',
         long: '--opertor OPERATION',
         default: 'equal'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
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
    client = Aws::EC2::Client.new aws_config

    filter = Filter.parse(config[:filter])

    if filter.empty?
      options = {}
    else
      options = { filters: filter }
    end

    data = client.describe_instances(options)

    instance_ids = Set.new

    data[:reservations].each do |res|
      res[:instances].each do |i|
        instance_ids << i[:instance_id]
      end
    end

    count = instance_ids.count
    op = convert_operator
    message = "Current count: #{count}"

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
  rescue => e
    puts "Error: exception: #{e}"
    critical
  end
end
