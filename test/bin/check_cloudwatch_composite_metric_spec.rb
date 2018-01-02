require 'aws-sdk'
require_relative '../../bin/check-cloudwatch-composite-metric.rb'
require_relative '../spec_helper.rb'

class CloudWatchCompositeMetricCheck
  at_exit do
    @@autorun = false
  end

  def critical(*)
    'triggered critical'
  end

  def warning(*)
    'triggered warning'
  end

  def ok(*)
    'triggered ok'
  end
end

describe 'CheckCloudWatchCompisteMetricCheck' do
  before :all do
    @check =  CloudWatchCompositeMetricCheck.new(['-N', 'numerator', '-D', 'denominator', '-c', '75'])
  end

  describe '#metric_desc' do
    it 'should return the description' do
      allow(@check).to receive(:dimension_string).and_return('dimensions')
      expect(@check.metric_desc).to eq('AWS/EC2-numerator/denominator(dimensions)')
    end
  end
end
