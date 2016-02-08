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
    if config[:aws_access_key] && config[:aws_secret_access_key]
      Aws.config[:credentials] = Aws::Credentials.new(config[:aws_access_key], config[:aws_secret_access_key])
    else
      # If the credentials aren't explicitly given then pull from the environment
      # using the default provider chain
      Aws.config[:credentials] = Aws::Credentials.new()
    end

    Aws.config.update(
      region: config[:aws_region]
    )
  end
end
