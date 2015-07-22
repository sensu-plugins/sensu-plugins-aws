#! /usr/bin/env ruby
#
# metrics-ec2-filter
#
# DESCRIPTION:
#   This plugin retrieves EC2 instances matching a given filter
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
#   ./metrics-ec2-filter.rb -f "{name:tag-value,values:[infrastructure]}"
#   ./metrics-ec2-filter.rb -f "{name:tag-value,values:[infrastructure]} {name:instance-state-name,values:[running]}"
#
# NOTES:
#
# LICENSE:
#   Justin McCarty
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk'

class EC2Filter < Sensu::Plugin::Metric::CLI::Graphite
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

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sensu.aws.ec2'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def convert_filter(input)
    filter = []
    items = input.scan(/{.*?}/)

    items.each do |item|
      if item.strip.empty?
        fail 'Invalid filter syntax'
      end

      entry = {}
      name = item.scan(/name:(.*?),/)
      value = item.scan(/values:\[(.*?)\]/)

      if name.nil? || name.empty? || value.nil? || value.empty?
        fail 'Unable to parse filter entry'
      end

      entry[:name] = name[0][0].strip
      entry[:values] = value[0][0].split(',')
      filter << entry
    end
    filter
  end

  def run
    begin
      client = Aws::EC2::Client.new aws_config

      filter = convert_filter(config[:filter])

      options = { filters: filter }

      data = client.describe_instances(options)

      instance_ids = Set.new
      scheme = config[:scheme]
      
      unless config[:name].empty?
        scheme += ".#{config[:name]}"
      end
      data[:reservations].each do |res|
        res[:instances].each do |i|
          instance_ids << i[:instance_id]
          output scheme + ".ids.#{i[:instance_id]}"
        end
      end
      output scheme + ".count.#{instance_ids.count}"
    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
