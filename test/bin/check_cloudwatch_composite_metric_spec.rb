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

  def unknown(*)
    'triggered unknown'
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

  describe '#numerator_data' do
    it 'should return default (nil) if response is empty' do
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      payload = client.stub_data(:get_metric_statistics)
      @check.config[:statistics] = 'average'
      expect(@check.numerator_data(payload)).to equal(nil)
    end

    it 'should return default (10) if response is empty' do
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      payload = client.stub_data(:get_metric_statistics)
      @check.config[:statistics] = 'average'
      @check.config[:numerator_default] = 10.to_f
      expect(@check.numerator_data(payload)).to equal(10.to_f)
    end

    it 'should return value if response is not empty' do
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      payload = client.stub_data(:get_metric_statistics, datapoints: [average: 20.to_f])
      @check.config[:statistics] = 'average'
      @check.config[:numerator_default] = 10.to_f
      expect(@check.numerator_data(payload)).to equal(20.to_f)
    end
  end

  describe '#composite_check' do
    it 'should exit unknown if any data is nil and no flags are passed' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'stats',
        unit: 'foo'
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp = client.stub_data(:get_metric_statistics)
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to eq(:unknown)
      expect(msg).to eq('test could not be retrieved')
    end

    it 'should exit ok if any data is nil but no_data_ok is true' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'stats',
        unit: 'foo',
        no_data_ok: true
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp = client.stub_data(:get_metric_statistics)
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to equal(:ok)
      expect(msg).to eq('test returned no data but that\'s ok')
    end

    it 'should exit ok if denominator data is nil but no_denominator_data_ok is true' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'stats',
        unit: 'foo',
        no_denominator_data_ok: true
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp = client.stub_data(:get_metric_statistics)
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to equal(:ok)
      expect(msg).to eq('denominator_metric_name returned no data but that\'s ok')
    end

    it 'should exit unknown if denominator data is zero with no flags passed' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'average',
        unit: 'foo',
        no_denominator_data_ok: true
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp = client.stub_data(:get_metric_statistics, datapoints: [average: 0.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to eq(:unknown)
      expect(msg).to eq('test: denominator value is zero')
    end

    it 'should exit ok if denominator data is zero with zero_denominator_data_ok passed' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'average',
        unit: 'foo',
        zero_denominator_data_ok: true
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp = client.stub_data(:get_metric_statistics, datapoints: [average: 0.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to eq(:ok)
      expect(msg).to eq('test: denominator value is zero but that\'s ok')
    end

    it 'should exit ciritical if below threshold' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'average',
        unit: 'foo',
        compare: 'less',
        critical: 75
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp_num = client.stub_data(:get_metric_statistics, datapoints: [average: 5.to_f])
      aws_resp_den = client.stub_data(:get_metric_statistics, datapoints: [average: 10.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp_num, aws_resp_den)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to eq(:critical)
      expect(msg).to eq('test is 50: comparison=less threshold=75')
    end

    it 'should exit warning if below threshold' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'average',
        unit: 'foo',
        compare: 'less',
        critical: 30,
        warning: 74
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp_num = client.stub_data(:get_metric_statistics, datapoints: [average: 5.to_f])
      aws_resp_den = client.stub_data(:get_metric_statistics, datapoints: [average: 10.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp_num, aws_resp_den)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to eq(:warning)
      expect(msg).to eq('test is 50: comparison=less threshold=74')
    end

    it 'should exit ok if above threshold' do
      config = {
        namespace: 'namespace',
        numerator_metric_name: 'numerator_metric_name',
        denominator_metric_name: 'denominator_metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'average',
        unit: 'foo',
        compare: 'less',
        critical: 30
      }
      @check.config = config
      client = Aws::CloudWatch::Client.new(stub_responses: true)
      aws_resp_num = client.stub_data(:get_metric_statistics, datapoints: [average: 5.to_f])
      aws_resp_den = client.stub_data(:get_metric_statistics, datapoints: [average: 10.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp_num, aws_resp_den)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp, msg = @check.composite_check
      expect(resp).to eq(:ok)
      expect(msg).to eq('test is 50: comparison=less, will alarm at 30')
    end
  end

  describe '#run' do
    it 'should recognize :ok status' do
      allow(@check).to receive(:composite_check).and_return(:ok, 'yay')
      ## We overrode so it doesn't exit
      expect(@check.run).to eq('triggered ok')
    end

    it 'should recognize :critical status' do
      allow(@check).to receive(:composite_check).and_return(:critical, 'yay')
      ## We overrode so it doesn't exit
      expect(@check.run).to eq('triggered critical')
    end

    it 'should recognize :warning status' do
      allow(@check).to receive(:composite_check).and_return(:warning, 'yay')
      ## We overrode so it doesn't exit
      expect(@check.run).to eq('triggered warning')
    end

    it 'should recognize :unknown status' do
      allow(@check).to receive(:composite_check).and_return(:unknown, 'yay')
      ## We overrode so it doesn't exit
      expect(@check.run).to eq('triggered unknown')
    end

    it 'should return unknown if other exit code is called' do
      allow(@check).to receive(:composite_check).and_return(:foo, 'yay')
      ## We overrode so it doesn't exit
      expect(@check.run).to eq('triggered unknown')
    end
  end
end
