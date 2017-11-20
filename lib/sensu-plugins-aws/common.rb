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
  def initialize(argv = ARGV)
    super(argv)
    aws_config
  end

  def aws_config
    Aws.config[:credentials] = Aws::Credentials.new(config[:aws_access_key], config[:aws_secret_access_key]) if config[:aws_access_key] && config[:aws_secret_access_key]

    # the cop can't figure out whether it should be a single guard or
    # a multiple line if. Due to poor detection in this case we left as
    # is an opted to disable and keep existing.
    Aws.config.update( # rubocop:disable Style/MultilineIfModifier
      region: config[:aws_region]
    ) if config.key?(:aws_region)
  end
end
