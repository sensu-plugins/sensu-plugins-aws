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
#   ./check-s3-bucket.rb --bucket-name mybucket --aws-region eu-west-1
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Olivier Bazoud and Ricky Hussmann,
#     olivier.bazoud@gmail.com, ricky.hussmann@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckS3Bucket < Sensu::Plugin::Check::CLI
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

  option :aws_session_token,
         short: '-t AWS_SESSION_TOKEN',
         long: '--aws-session-token TOKEN',
         description: 'AWS Session Token',
         default: ENV['AWS_SESSION_TOKEN']

  option :bucket_name,
         short: '-b BUCKET_NAME',
         long: '--bucket-name',
         description: 'The name of the S3 bucket to check',
         required: true

  option :use_iam_role,
         short: '-u',
         long: '--use-iam',
         description: 'Use IAM role authenticiation. Instance must have IAM role assigned for this to work'

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      session_token: config[:session_token],
      region: config[:aws_region] }
  end

  def website_configuration?(s3, bucket_name)
    s3.get_bucket_website(bucket: bucket_name)
    true
  rescue Aws::S3::Errors::NoSuchWebsiteConfiguration
    false
  end

  def get_bucket_policy(s3, bucket_name)
    JSON.parse(s3.get_bucket_policy(bucket: bucket_name).policy.string)
  rescue Aws::S3::Errors::NoSuchBucketPolicy
    { 'Statement' => [] }
  end

  def policy_too_permissive(policy)
    policy['Statement'].any? { |s| statement_too_permissive s }
  end

  def statement_too_permissive(s)
    actions_contain_get_or_list Array(s['Action'])
  end

  def actions_contain_get_or_list(actions)
    actions.any? { |a| !Array(a).grep(/^s3:Get|s3:List/).empty? }
  end

  def run
    aws_config = {}

    if config[:use_iam_role].nil?
      aws_config[:access_key_id] = config[:aws_access_key]
      aws_config[:secret_access_key] = config[:aws_secret_access_key]
      aws_config[:session_token] = config[:aws_session_token]
    end

    s3 = Aws::S3::Client.new(aws_config.merge!(region: config[:aws_region]))
    begin
      errors = []
      if website_configuration?(s3, config[:bucket_name])
        errors.push 'Website configuration found'
      end
      if policy_too_permissive(get_bucket_policy(s3, config[:bucket_name]))
        errors.push 'Bucket policy too permissive'
      end

      if !errors.empty?
        critical errors.join '; '
      else
        ok "Bucket #{config[:bucket_name]} not exposed via website or bucket policy"
      end
    rescue Aws::S3::Errors::NotFound => _
      critical "Bucket #{config[:bucket_name]} not found"
    end
  end
end
