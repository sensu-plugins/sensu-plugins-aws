#! /usr/bin/env ruby
#
# check-ses-limit
#
# DESCRIPTION:
#   Gets your SES sending limit and issues a warn and critical based on percentages
#   you supply for your daily sending limit
#   Checks how close you are getting in percentages to your 24 hour ses sending limit
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
#   gem: sensu-plugins-aws
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Joel <jjshoe@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckSESLimit < Sensu::Plugin::Check::CLI
  include Common
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: 'AWS Access Key ID.'

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: 'AWS Secret Access Key.'

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :warn_percent,
         short: '-W WARN_PERCENT',
         long: '--warn_perc WARN_PERCENT',
         description: 'Warn when the percentage of mail sent is at or above this number',
         default: 75,
         proc: proc(&:to_i)

  option :crit_percent,
         short: '-C CRIT_PERCENT',
         long: '--crit_perc CRIT_PERCENT',
         description: 'Critical when the percentage of mail sent is at or above this number',
         default: 90,
         proc: proc(&:to_i)

  def run
    begin
      ses = Aws::SES::Client.new
      response = ses.get_send_quota
    rescue StandardError => e
      unknown "An issue occured while communicating with the AWS SES API: #{e.message}"
    end

    unknown 'Empty response from AWS SES API' if response.empty? # Can this happen?

    percent = ((response.sent_last_24_hours.to_f / response.max_24_hour_send.to_f) * 100).to_i
    message = "SES sending limit is at #{percent}%"

    if config[:crit_percent] > 0 && config[:crit_percent] <= percent
      critical message
    elsif config[:warn_percent] > 0 && config[:warn_percent] <= percent
      warning message
    else
      ok message
    end
  end
end
