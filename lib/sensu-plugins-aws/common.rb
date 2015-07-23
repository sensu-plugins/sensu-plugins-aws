#
# DESCRIPTION:
#   Common helper methods
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Shane Starcher <shane.starcher@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

module Common
  def initialize
    super()
    aws_config
  end

  def aws_config
    Aws.config.update(
      credentials: Aws::Credentials.new(config[:aws_access_key], config[:aws_secret_access_key])
    ) if config[:aws_access_key] && config[:aws_secret_access_key]

    Aws.config.update(
      region: config[:aws_region]
    )
  end

  def convert_filter(input)
    filter = []
    items = input.scan(/{.*?}/)

    items.each do |item|
      if item.strip.empty?
        fail 'Invalid filter syntax'
      end

      entry = {}
      name = item.scan(/name:(.*?),/)
      value = item.scan(/values:\[(.*?)\]/)

      if name.nil? || name.empty? || value.nil? || value.empty?
        fail 'Unable to parse filter entry'
      end

      entry[:name] = name[0][0].strip
      entry[:values] = value[0][0].split(',')
      filter << entry
    end
    filter
  end
end
