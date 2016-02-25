#! /usr/bin/env ruby
#
# check-ebs-snapshots
#
# DESCRIPTION:
#   Check EC2 Attached Volumes for Snapshots.  Only for Volumes with a Name tag.
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
#   ./check-ebs-snapshots.rb -r ${you_region}
#   ./check-ebs-snapshots.rb -r ${you_region} -p 1
#   ./check-ebs-snapshots.rb -r ${you_region} -p -i
#   ./check-ebs-snapshots.rb -r ${you_region} -i
#
# NOTES:
#   When using -i flag any volume that has a tag-key of "IGNORE_BACKUP" will
#   be ignored.
#
# LICENSE:
#   Shane Starcher <shane.starcher@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckEbsSnapshots < Sensu::Plugin::Check::CLI
  include Common
  option :period,
         short:       '-p N',
         long:        '--period Days',
         default:     7,
         description: 'Length in time to alert on missing snapshots'

  option :aws_region,
         short:       '-r R',
         long:        '--region REGION',
         description: 'AWS region',
         default: 'us-east-1'

  option :check_ignored,
         short:       '-i',
         long:        '--ignore',
         description: 'mark as true to ignore volumes with an IGNORE_BACKUP tag',
         default: false,
         boolean: true

  def run
    errors = []
    @ec2 = Aws::EC2::Client.new

    volumes = @ec2.describe_volumes(
      filters: [
        {
          name: 'attachment.status',
          values: ['attached']
        },
        {
          name: 'tag-key',
          values: ['Name']
        }
      ]
    )
    volumes[:volumes].each do |volume|
      tags = volume[:tags].map { |a| Hash[*a] }.reduce(:merge) || {}
      next if config[:check_ignored] && tags.key?('IGNORE_BACKUP')
      snapshots = @ec2.describe_snapshots(
        filters: [
          {
            name: 'volume-id',
            values: [volume[:volume_id]]
          }
        ]
      )

      sorted_times = snapshots[:snapshots].sort_by { |i| i[:start_time].to_i }
      if !sorted_times.empty?
        latest_snapshot = sorted_times[-1][:start_time]
        if (Date.today - config[:period].to_i).to_time > latest_snapshot
          errors << "#{tags['Name']} latest snapshot is #{latest_snapshot} for #{volume[:volume_id]}"
        end
      else
        errors << " #{tags['Name']} has no snapshots for #{volume[:volume_id]}"
      end
    end

    if errors.empty?
      ok
    else
      warning errors.join("\n")
    end
  end
end
