#! /usr/bin/env ruby
#
# check-ebs-burst-limit
#
# DESCRIPTION:
#   Check EC2 Volumes for volumes with low burst balance
#   Optionally check only volumes attached to the current instance
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
#   ./check-ebs-burst-limit.rb -r ${you_region}
#   ./check-ebs-burst-limit.rb -r ${you_region} -c 50
#   ./check-ebs-burst-limit.rb -r ${you_region} -c 50 -t Name
#   ./check-ebs-burst-limit.rb -r ${you_region} -w 50 -c 10
#   ./check-ebs-burst-limit.rb -r ${you_region} -w 50 -c 10 -f "{name:tag-value,values:[infrastructure]}"
#   ./check-ebs-burst-limit.rb -r ${you_region} -w 50 -c 10 -f "{name:tag-value,values:[infrastructure]}" -t Name
#
# LICENSE:
#   Barry Martin <nyxcharon@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'sensu-plugins-aws/filter'
require 'aws-sdk'
require 'net/http'

class CheckEbsBurstLimit < Sensu::Plugin::Check::CLI
  include CloudwatchCommon
  include Filter

  option :aws_region,
         short:       '-r R',
         long:        '--region REGION',
         description: 'AWS region, will be overridden by the -s option',
         default: 'us-east-1'

  option :tag,
         description: 'Add volume TAG value to warn/critical message.',
         short: '-t TAG',
         long: '--tag TAG'

  option :critical,
         description: 'Trigger a critical when ebs burst limit is under VALUE',
         short: '-c VALUE',
         long: '--critical VALUE',
         proc: proc(&:to_f),
         required: true

  option :warning,
         description: 'Trigger a warning when ebs burst limit is under VALUE',
         short: '-w VALUE',
         long: '--warning VALUE',
         proc: proc(&:to_f)

  option :check_self,
         short: '-s',
         long: '--check-self',
         description: 'Only check the instance on which this plugin is being run - this overrides the -r option and uses the region of the current instance',
         boolean: true,
         default: false

  option :filter,
         short: '-f FILTER',
         long: '--filter FILTER',
         description: 'String representation of the filter to apply',
         default: '{}'

  def volume_tag(volume, tag_name)
    tag = volume.tags.select { |t| t.key == tag_name }.first
    tag.nil? ? '' : tag.value
  end

  def run
    errors = []

    volume_filters = Filter.parse(config[:filter])

    # Set the describe-volumes filter depending on whether -s was specified
    if config[:check_self] == true
      # Get the region from the availability zone, and override the -r option
      my_instance_az = Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/placement/availability-zone'))
      Aws.config[:region] = my_instance_az.chop
      my_instance_id = Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/instance-id'))
      volume_filters.push(
        name: 'attachment.instance-id',
        values: [my_instance_id]
      )
    else
      # The -s option was not specified, look at all volumes which are attached
      volume_filters.push(
        name: 'attachment.status',
        values: ['attached']
      )
    end

    ec2 = Aws::EC2::Client.new
    volumes = ec2.describe_volumes(
      filters: volume_filters
    )
    config[:metric_name] = 'BurstBalance'
    config[:namespace] = 'AWS/EBS'
    config[:statistics] = 'Average'
    config[:period] = 120
    crit = false
    should_warn = false

    volumes[:volumes].each do |volume|
      config[:dimensions] = []
      config[:dimensions] << { name: 'VolumeId', value: volume[:volume_id] }
      volume_tag = config[:tag] ? " (#{volume_tag(volume, config[:tag])})" : ''
      resp = client.get_metric_statistics(metrics_request(config))
      unless resp.datapoints.first.nil?
        if resp.datapoints.first[:average] < config[:critical]
          errors << "#{volume[:volume_id]}#{volume_tag} #{resp.datapoints.first[:average]}"
          crit = true
        elsif config[:warning] && resp.datapoints.first[:average] < config[:warning]
          errors << "#{volume[:volume_id]}#{volume_tag} #{resp.datapoints.first[:average]}"
          should_warn = true
        end
      end
    end

    if crit
      critical "Volume(s) have exceeded critical threshold: #{errors}"
    elsif should_warn
      warning "Volume(s) have exceeded warning threshold: #{errors}"
    else
      ok 'No volume(s) exceed thresholds'
    end
  end
end
