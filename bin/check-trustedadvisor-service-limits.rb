#! /usr/bin/env ruby
#
# check-trustedadvisor-service-limits
#
#
# DESCRIPTION:
#   This plugin uses Trusted Advisor API to perform check for
#   service limits. Trigger 'critical' on sensu for services
#   that are not 'Green'.
#
#   IAM requires AWSSupportAccess policy enabled.
#
#   https://aws.amazon.com/premiumsupport/ta-faqs/
#
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
#  ./check-trustedadvisor-service-limits.rb -l {en|ja}
#
# NOTES:
#
# LICENSE:
#   Seandy Wibowo <swibowo@sugarcrm.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckTrustedAdvisorServiceLimits < Sensu::Plugin::Check::CLI
  include Common
  option :aws_language,
         short: '-l AWS_LANGUAGE',
         long: '--aws-language AWS_LANGUAGE',
         description: "ISO 639-1 language code to be used when querying Trusted Advisor API. Only 'en' and 'ja' supported for now",
         default: 'en'

  def aws_support
    # The Support endpoint seems to only available in us-east-1 region
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/Support.html
    @aws_support ||= Aws::Support::Client.new(region: 'us-east-1')
  end

  def run
    service_limit_msg = []

    begin
      # Get all check IDs with category "service_limits"
      check_ids = []
      aws_support.describe_trusted_advisor_checks(language: config[:aws_language])[:checks].each { |c| check_ids << c.id if c.category == 'service_limits' }

      # Get all checks that are not "ok"
      checks_not_ok = []
      aws_support.describe_trusted_advisor_check_summaries(check_ids: check_ids)[:summaries].each { |c| checks_not_ok << c.check_id if c.status != 'ok' }

      checks_not_ok.each do |cno|
        aws_support.describe_trusted_advisor_check_result(language: config[:aws_language], check_id: cno)[:result][:flagged_resources].each do |slr|
          # Data structure will be as follow
          # ["<region>", "<service>", "<description>", "<limit>", "<usage>", "<status>"]
          sl_region, sl_service, sl_description, sl_limit, sl_usage, sl_status = slr[:metadata]

          next if slr.status == 'ok' || sl_status == 'Green'

          sl_usage = 0 if sl_usage.nil?

          sl_msg = "#{sl_service} (#{sl_region}) #{sl_description} #{sl_usage} out of #{sl_limit}"
          service_limit_msg.push(sl_msg)
        end
      end
    rescue StandardError => e
      unknown "An error occurred processing AWS TrustedAdvisor API: #{e.message}"
    end

    if service_limit_msg.empty?
      ok
    else
      critical("Services hitting usage limit: #{service_limit_msg.join(', ')}")
    end
  end
end
