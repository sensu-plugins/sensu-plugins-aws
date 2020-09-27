#! /usr/bin/env ruby
#
# expiring-reservations
#
# DESCRIPTION:
#   Alert on expiring reservations of an AWS account.
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
#   check-expiring-reservations.rb
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2019, Nicolas Boutet amd3002@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'

class CheckExpiringReservations < Sensu::Plugin::Check::CLI
  include Common

  option :reservation_id,
         description: 'Reservation id (defaults to all reservations if omitted)',
         short:       '-R RESERVATION_ID',
         long:        '--reservation-id RESERVATION_ID',
         default:     nil

  option :offering_class,
         description: 'The offering class of the Reserved Instance (standard or convertible)',
         short:       '-o OFFERING_CLASS',
         long:        '--offering-class OFFERING_CLASS',
         default:     'standard'

  option :aws_region,
         short:       '-r AWS_REGION',
         long:        '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default:     'us-east-1'

  option :warning,
         short:       '-w N',
         long:        '--warning VALUE',
         description: 'Issue a warning if a reservation will expire in under VALUE days',
         default:     0,
         proc:        proc(&:to_i)

  option :critical,
         short:       '-c N',
         long:        '--critical VALUE',
         description: 'Issue a critical if a reservation will expire in under VALUE days',
         default:     1,
         proc:        proc(&:to_i)

  def run
    begin
      client = Aws::EC2::Client.new(aws_config)

      params = {
        filters: [
          {
            name: 'state',
            values: ['active']
          }
        ],
        offering_class: config[:offering_class]
      }

      unless config[:reservation_id].nil?
        params[:reserved_instances_ids] = [config[:reservation_id]]
      end

      reservations = client.describe_reserved_instances(params)

      warnflag = false
      critflag = false
      reportstring = ''

      reservations.reserved_instances.each do |reservation|
        time_left = (reservation.end - Time.now).abs.to_i / (24 * 60 * 60)

        if time_left <= config[:critical]
          critflag = true
          reportstring += " reservation #{reservation.reserved_instances_id} (#{reservation.instance_type} x #{reservation.instance_count}) expires in #{time_left} days;"
        elsif time_left <= config[:warning]
          warnflag = true
          reportstring += " reservation #{reservation.reserved_instances_id} (#{reservation.instance_type} x #{reservation.instance_count}) expires in #{time_left} days;"
        end
      end

      if critflag
        critical reportstring
      elsif warnflag
        warning reportstring
      else
        ok 'All checked reservations are ok'
      end
    rescue StandardError => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
