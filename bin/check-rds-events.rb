#! /usr/bin/env ruby
#
# check-rds-events
#
#
# DESCRIPTION:
#   This plugin checks rds clusters for critical events.
#   Due to the number of events types on RDS clusters, the check
#   should filter out non-disruptive events that are part of
#   basic operations.
#
#   More info on RDS events:
#   http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Events.html
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
#  ./check-rds-events.rb -r ${your_region} -k ${your_aws_secret_access_key} -a ${your_aws_access_key}
#
# NOTES:
#
# LICENSE:
#   Tim Smith <tim@cozy.co>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

class CheckRDSEvents < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short:       '-a AWS_ACCESS_KEY',
         long:        '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default:     ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short:       '-k AWS_SECRET_KEY',
         long:        '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default:     ENV['AWS_SECRET_KEY']

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def run
    clusters = maint_clusters
    if clusters.empty?
      ok
    else
      critical("Clusters w/ critical events: #{clusters.join(', ')}")
    end
  end

  def maint_clusters
    rds = AWS::RDS::Client.new aws_config

    begin
      # fetch all clusters identifiers
      clusters = rds.describe_db_instances[:db_instances].map { |db| db[:db_instance_identifier] }
      maint_clusters = []

      # fetch the last 15 minutes of events for each cluster
      # that way, we're only spammed with persistent notifications that we'd care about.
      clusters.each do |cluster_name|
        events_record = rds.describe_events(start_time: (Time.now - 900).iso8601, source_type: 'db-instance', source_identifier: cluster_name)
        next if events_record[:events].empty?

        # we will need to filter out non-disruptive/basic operation events.
        # ie. the regular backup operations
        next if events_record[:events][-1][:message] =~ /Backing up DB instance|Finished DB Instance backup|Restored from snapshot/
        # ie. Replication resumed
        next if events_record[:events][-1][:message] =~ /Replication for the Read Replica resumed/
        # you can add more filters to skip more events.

        # draft the messages
        cluster_name_long = "#{cluster_name} (#{aws_config[:region]}) #{events_record[:events][-1][:message]}"
        maint_clusters.push(cluster_name_long)
      end
    rescue => e
      unknown "An error occurred processing AWS RDS API: #{e.message}"
    end
    maint_clusters
  end
end
