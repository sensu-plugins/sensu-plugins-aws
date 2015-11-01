#
# DESCRIPTION:
#   Filter methods for aws queries
#
# DEPENDENCIES:
#
# USAGE:
#   Filter.parse(string)
#
# NOTES:
#
# LICENSE:
#   Justin McCarty (jmccarty3@gmail.com)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

module Filter
  def self.parse(input)
    filter = []

    if input == '{}'
      return filter
    end

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
