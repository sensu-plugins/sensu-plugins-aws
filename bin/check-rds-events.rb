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
      critical("Clusters w/ critical events: #{clusters.join(',')}")
    end
  end

  def maint_clusters
    rds = AWS::RDS::Client.new aws_config

    begin
      # fetch all clusters identifiers
      clusters = rds.describe_db_instances[:db_instances].map { |db| db[:db_instance_identifier] }
      maint_clusters = []

      # fetch the last 2 hours of events for each cluster
      clusters.each do |cluster_name|
        events_record = rds.describe_events(start_time: (Time.now - 7200).iso8601, source_type: 'db-instance', source_identifier: cluster_name)
        next if events_record[:events].empty?

        # if the last event is a start maint event then the cluster is still in maint
        maint_clusters.push(cluster_name) if events_record[:events][-1][:message] =~ /has started|is being|off-line|shutdown/
      end
    rescue => e
      unknown "An error occurred processing AWS RDS API: #{e.message}"
    end
    maint_clusters
  end
end
