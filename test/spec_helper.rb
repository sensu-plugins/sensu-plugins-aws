RSpec.configure do |c|
  c.formatter = :documentation
  c.color = true
end

#
# DESCRIPTION:
#   Extension of common helper methods for testing.
#   Specifically, override trigger functions from Sensu::Plugin::Check::CLI
#   to enable better testability.
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
#   Norm MacLennan <nmaclennan@cimpress.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
module Common
  at_exit do
    @@autorun = false
  end

  def critical(msg = nil)
    "triggered critical: #{msg}"
  end

  def warning(msg = nil)
    "triggered warning: #{msg}"
  end

  def ok(msg = nil)
    "triggered ok: #{msg}"
  end

  def unknown(msg = nil)
    "triggered unknown: #{msg}"
  end
end
