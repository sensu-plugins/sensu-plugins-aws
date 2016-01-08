require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

RSpec.configure do |c|
  c.formatter = :documentation
  c.color = true
end
