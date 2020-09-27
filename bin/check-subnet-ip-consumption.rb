#! /usr/bin/env ruby
#
# check-subnet-ip-consumption
#
#
# DESCRIPTION:
#   This plugin uses the EC2 API to determine if any subnet in a given region
#   has consumed IP addresses such that the consumption exceeds a user-specified threshold.
#   This plugin additionally uses the IAM API to resolve the account alias,
#   if the user uses the -s/--show-account-alias flag.
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
#  ./check-subnet-ip-consumption.rb -a <access key> -k <secret key> -r <region> -t <integer percentage>
#
# NOTES:
#   Special thanks to Garrett Kuchta and Antonio Beyah for their assistance.
#
# LICENSE:
#   Nick Jacques <Nick.Jacques@target.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckSubnetIpConsumption < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :alert_threshold,
         short:       '-t <threshold percentage>',
         long:        '--threshold <threshold percentage>',
         proc:        proc { |a| a.to_i },
         default:     85,
         in:          (0..100).to_a,
         description: 'Threshold (in percent) of consumed IP addresses (per subnet) to alert on'

  option :show_friendly_names,
         short:       '-f',
         long:        '--show-friendly-names',
         boolean:     true,
         default:     false,
         description: 'Show friendly names (using the Name tag) for AWS objects such as subnets or VPCs'

  option :show_account_alias,
         short:       '-s',
         long:        '--show-account-alias',
         boolean:     true,
         default:     false,
         description: 'Show the account alias in the alert output. Requires IAM read privileges.'

  option :verbosity,
         short:       '-v <level>',
         long:        '--verbosity <level>',
         proc:        proc { |a| a.to_i },
         in:          (0..2).to_a,
         default:     0,
         description: 'Manipulate the verbosity of the alert output. Valid options are 0, 1, and 2 (from least to most verbose). Default is 0.'

  option :warn_only,
         short:       '-w',
         long:        '--warn-only',
         boolean:     true,
         default:     false,
         description: 'Warning only'

  def iam_client
    @iam_client ||= Aws::IAM::Client.new
  end

  def ec2_client
    @ec2_client ||= Aws::EC2::Client.new
  end

  # Returns the alias of the AWS account (if there is one), "<no name>" (if there is not), or nil if -s/--show-account-alias is not used.
  def account_alias
    # Do not execute IAM API call unless the -s/--show_account_alias flag is specified
    # (to prevent excess API calls *and* errors if IAM rights are not allowed)
    return nil unless config[:show_account_alias]

    begin
      iam_account_alias = iam_client.list_account_aliases[:account_aliases].first

      return '<no alias>' if iam_account_alias.empty? || iam_account_alias.nil?
      return iam_account_alias
    rescue StandardError => e
      unknown "An error occured while using AWS IAM to collect the account alias: #{e.message}"
    end
  end

  # Returns the value of the Name tag (if there is one) or "<no name>" (if there is not). Used with VPC and subnet objects.
  def extract_name_tag(tags)
    # Find the 'Name' key in the tags object and extract it. If the key isn't found, we get nil instead.
    name_tag = tags.find { |tag| tag.key == 'Name' }
    # If extracting the key/value was successful...
    if name_tag
      # ...extract the value (if there is one), or return <no name>
      !name_tag[:value].empty? ? name_tag[:value] : '<no name>'
    else
      # Otherwise, there's not a Name key, and thus the object has no name.
      '<no name>'
    end
  end

  # Returns the subnet's friendly name if -f/--show-friendly-names is used, otherwise returns the ID
  def display_subnet(alert)
    return alert[:subnet_name] if config[:show_friendly_names]
    alert[:subnet_id]
  end

  # Returns the VPC's friendly name if -f/--show-friendly-names is used, otherwise returns the ID
  def display_vpc(alert)
    return alert[:vpc_friendly_name] if config[:show_friendly_names]
    alert[:subnet_vpc_id]
  end

  def run
    # Subnets that meet the threshold criteria will store info hashes in this array
    consumption_alert = []

    begin
      subnets = ec2_client.describe_subnets[:subnets]

      subnets.each do |subnet|
        # subnet.cidr_block contains '0.0.0.0/0' notation. We want the mask number after the slash.
        subnet_netblock = subnet.cidr_block.split('/')[1].to_i
        # Subtract the mask number from 32 and use the result as the exponent of 2 to get the number of possible addresses in the netblock.
        # Then, subtract 5 from that number. Rationale: http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#VPC_Sizing
        # AWS reserves the first four addresses and the last address in any netblock.
        subnet_total_capacity = (2**(32 - subnet_netblock)) - 5
        # Determine how many IP addresses have been consumed
        subnet_consumed_capacity = (subnet_total_capacity - subnet.available_ip_address_count)
        # Divide consumed IPs by total IPs to get percentage. Multiply by 100 and round to get integer percents.
        subnet_consumed_pct = ((subnet_consumed_capacity.to_f / subnet_total_capacity.to_f) * 100).round(0)

        # Get the subnet's friendly name
        subnet_name_tag = extract_name_tag subnet[:tags]
        # Only get the VPC friendly names if explicitly asked for (otherwise this is a useless API hit)
        if config[:show_friendly_names]
          vpc = ec2_client.describe_vpcs(vpc_ids: [subnet.vpc_id])[:vpcs].first
          vpc_friendly_name = extract_name_tag vpc[:tags]
        end

        # Test if the subnet consumption % meets or exceeds the threshold %
        if subnet_consumed_pct >= config[:alert_threshold]
          # Add a hash containing subnet info to the consumption_alert array
          consumption_alert.push(subnet_id: subnet.subnet_id,
                                 subnet_name: subnet_name_tag,
                                 subnet_consumed_pct: subnet_consumed_pct,
                                 subnet_vpc_id: subnet.vpc_id,
                                 subnet_consumed_capacity: subnet_consumed_capacity,
                                 subnet_total_capacity: subnet_total_capacity,
                                 subnet_az: subnet[:availability_zone],
                                 cidr_block: subnet[:cidr_block],
                                 vpc_friendly_name: vpc_friendly_name)
        end
      end
    rescue StandardError => e
      unknown "An error occurred processing AWS EC2: #{e.message}"
    end

    # Process any alerts that might've been generated.
    if consumption_alert.empty?
      ok
    else
      # Compose alert messages at the configured verbosity
      alert_msg = []
      # TODO: Come back and re-asses Rubocop rule, following it's suggestion actually breaks the code
      # rubocop:disable Style/FormatStringToken
      verbosity0 = '%{subnet} at %{percent}%% [%{vpc}]'
      verbosity1 = '%{subnet} at %{percent}%% (%{consumed}/%{total}) [%{vpc}]'
      verbosity2 = '%{subnet} (%{cidr} in %{az}) at %{percent}%% (%{consumed}/%{total}) [%{vpc}]'
      # rubocop:enable Style/FormatStringToken

      case config[:verbosity]
      when 0
        consumption_alert.each do |alert|
          alert_msg.push(verbosity0 % { subnet: (display_subnet alert).to_s,
                                        percent: alert[:subnet_consumed_pct],
                                        vpc: (display_vpc alert).to_s })
        end
      when 1
        consumption_alert.each do |alert|
          alert_msg.push(verbosity1 % { subnet: (display_subnet alert).to_s,
                                        percent: alert[:subnet_consumed_pct],
                                        consumed: alert[:subnet_consumed_capacity],
                                        total: alert[:subnet_total_capacity],
                                        vpc: (display_vpc alert).to_s })
        end
      when 2
        consumption_alert.each do |alert|
          alert_msg.push(verbosity2 % { subnet: (display_subnet alert).to_s,
                                        cidr: alert[:cidr_block],
                                        az: alert[:subnet_az],
                                        percent: alert[:subnet_consumed_pct],
                                        consumed: alert[:subnet_consumed_capacity],
                                        total: alert[:subnet_total_capacity],
                                        vpc: (display_vpc alert).to_s })
        end
      end

      # Throw critical alert with optional account alias display
      # TODO: Come back and re-asses Rubocop rule, following it's suggestion actually breaks the code
      # rubocop:disable Style/FormatStringToken
      alert_prefix = '%{count} subnets in %{region} exceeding %{threshold}%% IP consumption threshold: %{alerts}'
      alert_prefix_with_alias = '%{count} subnets in %{alias} (%{region}) exceeding %{threshold}%% IP consumption threshold: %{alerts}'
      # rubocop:enable Style/FormatStringToken

      case config[:show_account_alias]
      when true
        alert_msg = alert_prefix_with_alias % { count: alert_msg.length,
                                                alias: account_alias,
                                                region: config[:aws_region],
                                                threshold: config[:alert_threshold],
                                                alerts: alert_msg.join(', ') }
      when false
        alert_msg = alert_prefix % { count: alert_msg.length,
                                     region: config[:aws_region],
                                     threshold: config[:alert_threshold],
                                     alerts: alert_msg.join(', ') }
      end

      case config[:warn_only]
      when true
        warning(alert_msg)
      when false
        critical(alert_msg)
      end
    end
  end
end
