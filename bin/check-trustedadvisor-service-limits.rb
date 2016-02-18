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
#  ./check-trustedadvisor-service-limits.rb -s ${your_aws_secret_access_key} -a ${your_aws_access_key}
#
# NOTES:
#
# LICENSE:
#   Seandy Wibowo <swibowo@sugarcrm.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

class CheckTrustedAdvisorServiceLimits < Sensu::Plugin::Check::CLI
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

  option :aws_language,
         short: '-l AWS_LANGUAGE',
         long: '--aws-language AWS_LANGUAGE',
         description: "ISO 639-1 language code to be used when querying Trusted Advisor API. Only 'en' and 'ja' supported for now",
         default: 'en'

  def run

    aws_support = AWS::Support::Client.new(
      access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key])

    service_limit_msg = []
 
    begin
      # service limit check
      # Perform a refresh to make sure the API result is not stale.
      sl_refresh = aws_support.refresh_trusted_advisor_check(check_id: 'eW7HH0l7J9')
      sl = aws_support.describe_trusted_advisor_check_result(check_id: 'eW7HH0l7J9', language: config[:aws_language])

      sl[:result][:flagged_resources].each do |slr|
        # Data structure will be as follow
        # ["<region>", "<service>", "<description>", "<limit>", "<usage>", "<status>"]
        sl_region, sl_service, sl_description, sl_limit, sl_usage, sl_status = slr[:metadata]

        next if sl_status == 'Green'
        sl_usage = 0 if sl_usage.nil?

        sl_msg = "#{sl_service} (#{sl_region}) #{sl_description} #{sl_usage} out of #{sl_limit}"
        service_limit_msg.push(sl_msg)
      end
    rescue => e
      unknown "An error occurred processing AWS TrustedAdvisor API: #{e.message}"
    end

    if service_limit_msg.empty?
      ok
    else
      critical("Services hitting usage limit: #{service_limit_msg.join(', ')}")
    end
  end
end
