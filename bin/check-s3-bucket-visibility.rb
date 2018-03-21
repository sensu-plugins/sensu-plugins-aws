#! /usr/bin/env ruby
#
# check-s3-bucket-visibility
#
# DESCRIPTION:
#   This plugin checks a bucket for website configuration and bucket policy.
#   It alerts if the bucket has a website configuration, or a policy that has
#   Get or List actions.
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
#   ./check-s3-bucket-visibility.rb --bucket-name mybucket --aws-region eu-west-1
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Olivier Bazoud and Ricky Hussmann,
#     olivier.bazoud@gmail.com, ricky.hussmann@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'aws-sdk-s3'
require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'

class CheckS3Bucket < Sensu::Plugin::Check::CLI
  include Common
  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :bucket_names,
         short: '-b BUCKET_NAMES',
         long: '--bucket-names',
         description: 'A comma seperated list of S3 buckets to check',
         proc: proc { |b| b.split(',') }

  option :all_buckets,
         short: '-a BOOL',
         long: '--all-buckets BOOL',
         description: 'If all buckets are true it will look at any buckets that we have access to in the region',
         boolean: true,
         default: false

  option :exclude_buckets,
         short: '-e EXCLUDED_BUCKETS_COMMA_SEPERATED',
         long: '--excluded-buckets EXCLUDED_BUCKETS_COMMA_SEPERATED',
         description: 'A comma seperated list of buckets to ignore that are expected to have loose permissions',
         proc: proc { |b| b.split(',') }

  option :exclude_regex_filter,
         long: '--exclude-regex-filter MY_REGEX',
         description: 'A regex to filter out bucket names'

  option :critical_on_missing,
         short: '-m ',
         long: '--critical-on-missing',
         description: 'The check will fail with CRITICAL rather than WARN when a bucket is not found',
         default: 'false'

  def true?(obj)
    !obj.nil? && obj.to_s.casecmp('true') != -1
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new
  end

  def s3_resource
    @s3_resource || Aws::S3::Resource.new
  end

  def list_buckets
    buckets = []
    s3_resource.buckets.each do |bucket|
      if s3_resource.client.get_bucket_location(bucket: bucket.name).location_constraint == config[:aws_region]
        buckets << bucket.name
      else
        p "skipping bucket: #{bucket.name} as is not in the region specified: #{config[:aws_region]}"
      end
    end
    buckets
  end

  def excluded_bucket?(bucket_name)
    return false if config[:exclude_buckets].nil?
    config[:exclude_buckets].include?(bucket_name)
  end

  def excluded_bucket_regex?(bucket_name)
    return false if config[:exclude_regex_filter].nil?
    if bucket_name.match(Regexp.new(Regexp.escape(config[:exclude_regex_filter])))
      true
    else
      false
    end
  end

  def website_configuration?(bucket_name)
    s3_client.get_bucket_website(bucket: bucket_name)
    true
  rescue Aws::S3::Errors::NoSuchWebsiteConfiguration
    false
  end

  def get_bucket_policy(bucket_name)
    JSON.parse(s3_client.get_bucket_policy(bucket: bucket_name).policy.string)
  rescue Aws::S3::Errors::NoSuchBucketPolicy
    { 'Statement' => [] }
  end

  def policy_too_permissive?(policy)
    policy['Statement'].any? { |s| statement_too_permissive? s }
  end

  def statement_too_permissive?(s)
    actions_contain_get_or_list? Array(s['Action'])
  end

  def actions_contain_get_or_list?(actions)
    actions.any? { |a| !Array(a).grep(/^s3:Get|s3:List|s3:\*/).empty? }
  end

  def run
    errors = []
    warnings = []
    buckets = if config[:all_buckets]
                list_buckets
              elsif config[:bucket_names] && !config[:bucket_names].empty?
                config[:bucket_names]
              else
                unknown 'you must specify either all buckets or provide list of buckets'
              end

    buckets.each do |bucket_name|
      if excluded_bucket?(bucket_name)
        p "bucket_name: #{bucket_name} was ignored as it matched excluded_buckets"
        next
      elsif excluded_bucket_regex?(bucket_name)
        p "bucket_name: #{bucket_name} was ignored as it matched exclude_regex_filter: #{Regexp.new(Regexp.escape(config[:exclude_regex_filter]))}"
        next
      end
      begin
        if website_configuration?(bucket_name)
          errors.push "#{bucket_name}: website configuration found"
        end
        if policy_too_permissive?(get_bucket_policy(bucket_name))
          errors.push "#{bucket_name}: bucket policy too permissive"
        end
      rescue Aws::S3::Errors::NoSuchBucket
        mesg = "Bucket #{bucket_name} not found"
        true?(config[:critical_on_missing]) ? errors.push(mesg) : warnings.push(mesg)
      end
    end

    if !errors.empty?
      critical errors.join '; '
    elsif !warnings.empty?
      warning warnings.join '; '
    else
      ok "#{buckets.join ','} not exposed via website or bucket policy"
    end
  end
end
