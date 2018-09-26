#! /usr/bin/env ruby
#
# check-s3-object
#
# DESCRIPTION:
#   This plugin checks if a file exists in a bucket and/or is not too old.
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
#   ./check-s3-object.rb --bucket-name mybucket --aws-region eu-west-1 --use-iam --key-name "path/to/myfile.txt"
#   ./check-s3-object.rb --bucket-name mybucket --aws-region eu-west-1 --use-iam --key-name "path/to/myfile.txt" --warning 90000 --critical 126000
#   ./check-s3-object.rb --bucket-name mybucket --aws-region eu-west-1 --use-iam --key-name "path/to/myfile.txt" --warning 90000 --critical 126000 --ok-zero-size
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Olivier Bazoud, olivier.bazoud@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckS3Object < Sensu::Plugin::Check::CLI
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

  option :bucket_name,
         short: '-b BUCKET_NAME',
         long: '--bucket-name',
         description: 'The name of the S3 bucket where object lives',
         required: true

  option :key_name,
         short: '-n KEY_NAME',
         long: '--key-name',
         description: 'The name of key in the bucket'

  option :key_prefix,
         short: '-p KEY_PREFIX',
         long: '--key-prefix',
         description: 'Prefix key to search on the bucket'

  option :warning_age,
         description: 'Warn if mtime greater than provided age in seconds',
         short: '-w SECONDS',
         long: '--warning SECONDS'

  option :critical_age,
         description: 'Critical if mtime greater than provided age in seconds',
         short: '-c SECONDS',
         long: '--critical SECONDS'

  option :ok_zero_size,
         description: 'OK if file has zero size',
         short: '-z',
         long: '--ok-zero-size',
         boolean: true,
         default: false

  option :warning_size,
         description: 'Warning threshold for size',
         long: '--warning-size COUNT'

  option :critical_size,
         description: 'Critical threshold for size',
         long: '--critical-size COUNT'

  option :compare_size,
         description: 'Comparision operator for threshold: equal, not, greater, less',
         short: '-o OPERATION',
         long: '--operator-size OPERATION',
         default: 'equal'

  option :no_crit_on_multiple_objects,
         description: 'If this flag is set, sort all matching objects by last_modified date and check against the newest. By default, this check will return a CRITICAL result if multiple matching objects are found.',
         short: '-m',
         long: '--ok-on-multiple-objects',
         boolean: true

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def operator
    op = lambda do |type, a, b|
      case type
      when 'age'
        a > b
      when 'size'
        if config[:compare_size] == 'greater'
          a > b
        elsif config[:compare_size] == 'less'
          a < b
        elsif config[:compare_size] == 'not'
          a != b
        end
      else
        a == b
      end
    end
    op
  end

  def run_check(type, level, value, element, msg)
    key = "#{level}_#{type}".to_sym
    return if config[key].nil?
    to_check = config[key].to_i
    send(level, msg % [element, value, config[:bucket_name]]) if operator.call type, value, to_check
  end

  def run
    aws_config = {}

    if (config[:key_name].nil? && config[:key_prefix].nil?) || (!config[:key_name].nil? && !config[:key_prefix].nil?)
      critical 'Need one option between "key_name" and "key_prefix"'
    end

    if config[:use_iam_role].nil?
      aws_config[:access_key_id] = config[:aws_access_key]
      aws_config[:secret_access_key] = config[:aws_secret_access_key]
    end

    s3 = Aws::S3::Client.new(aws_config.merge!(region: config[:aws_region]))
    begin
      if !config[:key_name].nil?
        key_search = config[:key_name]
        key_fullname = key_search
        output = s3.head_object(bucket: config[:bucket_name], key: key_search)
        age = Time.now.to_i - output[:last_modified].to_i
        size = output[:content_length]
      elsif !config[:key_prefix].nil?
        key_search = config[:key_prefix]
        output = s3.list_objects(bucket: config[:bucket_name], prefix: key_search)
        output = output.next_page while output.next_page?

        if output.contents.size.to_i < 1
          critical "Object with prefix \"#{key_search}\" not found in bucket #{config[:bucket_name]}"
        end

        if output.contents.size.to_i > 1
          if config[:no_crit_on_multiple_objects].nil?
            critical "Your prefix \"#{key_search}\" return too much files, you need to be more specific"
          else
            output.contents.sort_by!(&:last_modified).reverse!
          end
        end

        key_fullname = output.contents[0].key
        age = Time.now.to_i - output.contents[0].last_modified.to_i
        size = output.contents[0].size
      end

      %i[critical warning].each do |level|
        run_check('age', level, age, key_fullname, 'S3 object %s is %s seconds old (bucket %s)')
      end

      if size.zero?
        critical "S3 object #{key_fullname} is empty (bucket #{config[:bucket_name]})" unless config[:ok_zero_size]
      else
        %i[critical warning].each do |level|
          run_check('size', level, size, key_fullname, 'S3 %s object\'size : %s octets (bucket %s)')
        end
      end

      ok("S3 object #{key_fullname} exists in bucket #{config[:bucket_name]}")
    rescue Aws::S3::Errors::NotFound => _
      critical "S3 object #{key_fullname} not found in bucket #{config[:bucket_name]}"
    rescue StandardError => e
      critical "S3 object #{key_fullname} in bucket #{config[:bucket_name]} - #{e.message} - #{e.backtrace}"
    end
  end
end
