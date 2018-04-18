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
#  Check's a specific RDS instance in a specific region for critical events
#  check-rds-events.rb -r ${your_region} -k ${your_aws_secret_access_key} -a ${your_aws_access_key} -i ${your_rds_instance_id_name}
#
#  Checks all RDS instances in a specific region
#  check-rds-events.rb -r ${your_region} -k ${your_aws_secret_access_key} -a ${your_aws_access_key}
#
#  Checks all RDS instances in a specific region, should be using IAM role
#  check-rds-events.rb -r ${your_region}
#
# NOTES:
#
# LICENSE:
#   Tim Smith <tsmith@chef.io>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

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

  option :db_instance_id,
         short:       '-i N',
         long:        '--db-instance-id NAME',
         description: 'DB instance identifier'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def rds_regions
    Aws.partition('aws').regions.map(&:name)
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
    maint_clusters = []
    aws_regions = rds_regions

    unless config[:aws_region].casecmp('all').zero?
      if aws_regions.include? config[:aws_region]
        aws_regions.clear.push(config[:aws_region])
      else
        critical 'Invalid region specified!'
      end
    end

    aws_regions.each do |r|
      rds = Aws::RDS::Client.new aws_config.merge!(region: r)

      begin
        if !config[:db_instance_id].nil? && !config[:db_instance_id].empty?
          db_instance = rds.describe_db_instances(db_instance_identifier: config[:db_instance_id])
          if db_instance.nil? || db_instance.empty?
            unknown "#{config[:db_instance_id]} instance not found"
          else
            clusters = [config[:db_instance_id]]
          end
        else
          # fetch all clusters identifiers
          clusters = rds.describe_db_instances[:db_instances].map { |db| db[:db_instance_identifier] }
        end

        # fetch the last 15 minutes of events for each cluster
        # that way, we're only spammed with persistent notifications that we'd care about.
        clusters.each do |cluster_name|
          events_record = rds.describe_events(start_time: (Time.now.utc - 900).iso8601, source_type: 'db-instance', source_identifier: cluster_name)
          next if events_record[:events].empty?

          # we will need to filter out non-disruptive/basic operation events.
          # ie. the regular backup operations
          next if events_record[:events][-1][:message] =~ /Backing up DB instance|Finished DB Instance backup|Restored from snapshot/
          # ie. Replication resumed
          next if events_record[:events][-1][:message] =~ /Replication for the Read Replica resumed/
          # you can add more filters to skip more events.

          # draft the messages
          cluster_name_long = "#{cluster_name} (#{r}) #{events_record[:events][-1][:message]}"
          maint_clusters.push(cluster_name_long)
        end
      rescue StandardError => e
        unknown "An error occurred processing AWS RDS API (#{r}): #{e.message}"
      end
    end

    maint_clusters
  end
end
