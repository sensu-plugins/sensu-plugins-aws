#! /usr/bin/env ruby
#
# check-rds-events
#
#
# DESCRIPTION:
#   This plugin checks rds clusters for critical events.
#   Due to the number of events types on RDS clusters the check searches for
#   events containing the text string 'has started' or 'is being'.  These events all have
#   accompanying completiion events and are impacting events
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#  ./check-rds-events.rb -r ${you_region} -s ${your_aws_secret_access_key} -a ${your_aws_access_key}
#
# NOTES:
#
# LICENSE:
#   Tim Smith <tim@cozy.co>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckRDSEvents < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY_ID']

  option :aws_secret_access_key,
         short: '-s AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_ACCESS_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as eu-west-1).',
         default: 'us-east-1'

  def run # rubocop:disable AbcSize

    rds = Aws::RDS::Client.new(
      access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region])

    begin
      # fetch all clusters identifiers
      clusters = rds.describe_db_instances[:db_instances].map { |db| db[:db_instance_identifier] }
      maint_clusters = []
      # Check if there is any pending maintenance required 
      pending_record = rds.describe_pending_maintenance_actions(filters: [{name: "db-instance-id", values: clusters}] )
      pending_record[:pending_maintenance_actions].each do |response|
        maint_clusters.push(response[:pending_maintenance_action_details])
      end
    rescue => e
      unknown "An error occurred processing AWS RDS API: #{e.message}"
    end

    if maint_clusters.empty?
      ok
    else
      critical("Clusters w/ pending maintenance required: #{maint_clusters.join(',')}")
    end
  end
end
