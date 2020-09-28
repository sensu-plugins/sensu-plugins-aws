#! /usr/bin/env ruby
#
# check-instance-events
#
# DESCRIPTION:
#   This plugin looks up all instances in an account and alerts if one or more have a scheduled
#   event (reboot, retirement, etc)
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
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Tim Smith, tsmith@chef.io
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckInstanceEvents < Sensu::Plugin::Check::CLI
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

  option :use_iam_role,
         short: '-u',
         long: '--use-iam',
         description: 'Use IAM role authenticiation. Instance must have IAM role assigned for this to work'

  option :instance_id,
         short: '-i INSTANCE_IDS',
         long: '--instances INSTANCES_IDS',
         description: 'Comma separated list of instances ids to check. Defaults to all instances in the region',
         proc: proc { |a| a.split(',') },
         default: []

  option :include_name,
         short: '-n',
         long: '--include-name',
         description: "Includes any offending instance's 'Name' tag in the check output",
         default: false

  option :role,
         short:       '-R ASSUME_ROLE',
         long:        '--assume-role-arn ARN',
         description: 'IAM Role to assume'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def ec2_regions
    Aws.partition('aws').regions.map(&:name)
  end

  def assume_role
    role_config = aws_config

    # Delete keys so we can use an IAM role
    role_config.delete(:access_key_id)
    role_config.delete(:secret_access_key)

    Aws.config[:region] = role_config[:region]

    role_credentials = Aws::AssumeRoleCredentials.new(
      role_arn: config[:role],
      role_session_name: 'sensu-monitoring'
    )

    role_config.merge!(credentials: role_credentials)
  end

  def run
    event_instances = []
    aws_config = {}

    aws_regions = ec2_regions

    unless config[:aws_region].casecmp('all').zero?
      if aws_regions.include? config[:aws_region]
        aws_regions.clear.push(config[:aws_region])
      else
        critical 'Invalid region specified!'
      end
    end

    if config[:use_iam_role].nil?
      aws_config[:access_key_id] = config[:aws_access_key]
      aws_config[:secret_access_key] = config[:aws_secret_access_key]
    end

    # TODO: come back and refactor this
    aws_regions.each do |r| # Iterate each possible region # rubocop:disable Metrics/BlockLength)
      ec2 = Aws::EC2::Client.new(aws_config.merge!(region: r))
      begin
        describe_instance_options = {}
        if config[:instance_id].any?
          describe_instance_options = describe_instance_options.merge(instance_ids: config[:instance_id])
        end

        ec2.describe_instance_status(describe_instance_options).instance_statuses.each do |i|
          next if i[:events].empty?

          # Exclude completed reboots since the events API appearently returns these even after they have been completed:
          # Example:
          #  "events_set": [
          #     {
          #         "code": "system-reboot",
          #         "description": "[Completed] Scheduled reboot",
          #         "not_before": "2015-01-05 12:00:00 UTC",
          #         "not_after": "2015-01-05 18:00:00 UTC"
          #     }
          # ]
          useful_events =
            i[:events].reject { |x| (x[:code] =~ /system-reboot|instance-reboot|instance-stop|system-maintenance/) && (x[:description] =~ /\[Completed\]|\[Canceled\]/) }

          unless useful_events.empty?
            name = ''
            if config[:include_name]
              begin
                instance_desc = ec2.describe_instances(instance_ids: [i[:instance_id]])
                name_tag = instance_desc.reservations[0].instances[0].tags.find { |tag| tag[:key] == 'Name' }
                name = name_tag.nil? ? '' : name_tag.value
              rescue StandardError => e
                puts "Issue getting instance details for #{i[:instance_id]} (#{r}).  Exception = #{e}"
              end
            end

            event_instances << if name.empty?
                                 "#{i[:instance_id]} (#{r}) (#{i[:events][0][:code]}) #{i[:events][0][:description]}"
                               else
                                 "#{name} (#{i[:instance_id]} #{r}) (#{i[:events][0][:code]}) #{i[:events][0][:description]}"
                               end
          end
        end
      rescue StandardError => e
        unknown "An error occurred processing AWS EC2 API (#{r}): #{e.message}"
      end
    end

    if event_instances.count > 0
      critical("#{event_instances.count} instance#{event_instances.count > 1 ? 's have' : ' has'} upcoming scheduled events: #{event_instances.join(',')}")
    else
      ok
    end
  end
end
