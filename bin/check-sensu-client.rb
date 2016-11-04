#! /usr/bin/env ruby
#
# sensu-health-check
#
# DESCRIPTION:
#   Finds a given tag set from EC2 and ensures sensu clients exist
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
#   ./check-sensu-client.rb -w 20 -f "{name:tag-value,values:[infrastructure]}"
#   ./check-sensu-client.rb -w 20 -f "{name:tag-value,values:[infrastructure]}" -e '{Name:[Ignore, Bad.*]}'
#   ./check-sensu-client.rb -w 20 -f "{name:tag-value,values:[infrastructure]}" -e '{Name:[Ignore, Bad.*]} {Sensu: [Ignore]}'
#
# NOTES:
#  Values provided for the exclusion filter are treated as regex's for evaluation purposes. Any matching value
#  will result in the instance being excluded
#
# LICENSE:
#   Justin McCarty (jmccarty3@gmail.com)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'rest-client'
require 'json'

class CheckSensuClient < Sensu::Plugin::Check::CLI
  include Filter
  include Common
  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as us-east-1).',
         default: 'us-east-1'

  option :sensu_host,
         short: '-h SENSU_HOST',
         long: '--host SENSU_HOST',
         description: 'Sensu host to query',
         default: 'sensu'

  option :insecure,
         short: '-k',
         boolean: true,
         description: 'Enabling insecure connections',
         default: false

  option :sensu_port,
         short: '-p SENSU_PORT',
         long: '--port SENSU_PORT',
         description: 'Sensu API port',
         proc: proc(&:to_i),
         default: 4567

  option :warn,
         short: '-w WARN',
         description: 'Warn if instance has been up longer (Minutes)',
         proc: proc(&:to_i),
         default: 0

  option :critical,
         short: '-c CRITICAL',
         description: 'Critical if instance has been up longer (Minutes)',
         proc: proc(&:to_i)

  option :min,
         short: '-m MIN_TIME',
         description: 'Minimum Time an instance must be running (Minutes)',
         proc: proc(&:to_i),
         default: 5

  option :filter,
         short: '-f FILTER',
         description: 'Filter to use to find ec2 instances',
         default: '{}'

  option :exclude_tags,
         short: '-e {<tag-key>:[VAL1, VAL2]} {<tag-key>:[VAL1, VAL2] }',
         long: '--exclude_tags {<tag-key>:[VAL1, VAL2] } {<tag-key>:[VAL1, VAL2] }',
         description: 'Tag Values to exclude by. Values treated as regex. Any matching value will result in exclusion.',
         default: '{}'

  def run
    # Converting the string into a hash.
    filter_list = config[:exclude_tags].split(/}\s?{/).map do |x|
      x.gsub(/[{}]/, '')
    end
    filter_list = filter_list.map do |y|
      h1, h2 = y.split(':')
      { h1 => h2 }
    end.reduce(:merge)
    filter_list.delete(nil)
    filter_list.each { |x, y| filter_list[x] = y.strip.gsub(/[\[\]]/, '') }
    client = Aws::EC2::Client.new

    parsed_filter = Filter.parse(config[:filter])

    filter = if parsed_filter.empty?
               {}
             else
               { filters: parsed_filter }
             end

    data = client.describe_instances(filter)

    current_time = Time.now.utc
    aws_instances = Set.new
    data.reservations.each do |r|
      r.instances.each do |i|
        aws_instances << {
          id: i[:instance_id],
          up_time: (current_time - i[:launch_time]) / 60,
          tags: i.tags
        }
      end
    end

    sensu_clients = client_check

    missing = Set.new

    aws_instances.delete_if do |instance|
      instance[:tags].any? do |key|
        filter_list.keys.include?(key.key) && filter_list[key.key].split(',').any? do |v|
          key.value.match(/#{v.strip}/)
        end
      end
    end

    aws_instances.each do |i|
      if sensu_clients.include?(i[:id]) == false
        if i[:up_time] > config[:min]
          missing << i
          output "Missing instance #{i[:id]}. Uptime: #{i[:up_time]} Minutes"
        end
      end
    end

    warn_flag = false
    crit_flag = false

    missing.each do |m|
      if (config[:critical].nil? == false) && (m[:up_time] > config[:critical])
        crit_flag = true
      elsif (config[:warn].nil? == false) && (m[:up_time] > config[:warn])
        warn_flag = true
      end
    end

    if crit_flag
      critical
    elsif warn_flag
      warning
    end
    ok
  end

  def client_check
    verify_mode = OpenSSL::SSL::VERIFY_PEER
    verify_mode = OpenSSL::SSL::VERIFY_NONE if config[:insecure]
    request = RestClient::Resource.new("#{config[:sensu_host]}:#{config[:sensu_port]}/clients",
                                       verify_ssl: verify_mode)
    response = JSON.parse(request.get)

    clients = Set.new
    response.each do |client|
      clients << client['name']
    end

    clients
  end
end
