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
    Aws.config[:credentials] = Aws::Credentials.new()

    Aws.config.update(
      region: config[:aws_region]
    )
  end
end
