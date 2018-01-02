require 'aws-sdk'

class DummyCheck < Sensu::Plugin::Check::CLI
  at_exit do
    @@autorun = false
  end

  include CloudwatchCommon
end

describe 'CloudwatchCommon' do
  before :all do
    @check = DummyCheck.new
  end

  describe '#client' do
    it 'should return a cloudwatch client' do
      expect(@check.client).to be_instance_of(Aws::CloudWatch::Client)
    end

    it 'should memoize and return same client on subsequent calls' do
      client = @check.client
      expect(@check.client).to be(client)
    end
  end

  describe '#read_value' do
    it 'should return the last datapoint' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2000), average: 0.to_f }, { timestamp: Time.new(2010), average: 1.to_f }])
      value = @check.read_value(resp, 'average')
      expect(value).to equal(1.to_f)
    end

    it 'should sort by timestamp' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2010), average: 1.to_f }, { timestamp: Time.new(2000), average: 0.to_f }])
      value = @check.read_value(resp, 'average')
      expect(value).to equal(1.to_f)
    end
  end

  describe '#resp_has_no_data' do
    it 'should return true if datapoints is nil' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics)
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return true if datapoints is empty' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return true if the first datapoint is nil' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{}])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return true if the value is nil' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2010), average: nil }])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to be(true)
    end

    it 'should return false if valid data is present' do
      client = Aws::CloudWatch::Client.new
      resp = client.stub_data(:get_metric_statistics, datapoints: [{ timestamp: Time.new(2010), average: 1.to_f }, { timestamp: Time.new(2000), average: 0.to_f }])
      value = @check.resp_has_no_data(resp, 'average')
      expect(value).to equal(false)
    end
  end

  describe '#compare' do
    describe 'compare_method is less' do
      it 'should return true' do
        compare_method = 'less'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(true)
      end
      it 'should return false' do
        compare_method = 'less'
        result = @check.compare(10, 1, compare_method)
        expect(result).to be(false)
      end
    end

    describe 'compare_method is greater' do
      it 'should return false' do
        compare_method = 'greater'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(false)
      end
      it 'should return true' do
        compare_method = 'greater'
        result = @check.compare(10, 1, compare_method)
        expect(result).to be(true)
      end
    end

    describe 'compare_method is not' do
      it 'should return false' do
        compare_method = 'not'
        result = @check.compare(10, 10, compare_method)
        expect(result).to be(false)
      end
      it 'should return true' do
        compare_method = 'not'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(true)
      end
    end

    describe 'compare_method is equal' do
      it 'should return false' do
        compare_method = 'equal'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(false)
      end
      it 'should return true' do
        compare_method = 'equal'
        result = @check.compare(10, 10, compare_method)
        expect(result).to be(true)
      end
    end

    describe 'compare_method is foo' do
      it 'should return false' do
        compare_method = 'foo'
        result = @check.compare(1, 10, compare_method)
        expect(result).to be(false)
      end
      it 'should return true' do
        compare_method = 'foo'
        result = @check.compare(10, 10, compare_method)
        expect(result).to be(true)
      end
    end
  end

  describe '#metrics_reuquest' do
    it 'should return the proper payload' do
      config = {
        namespace: 'namespace',
        metric_name: 'metric_name',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'stats',
        unit: 'foo'
      }
      resp = @check.metrics_request(config)
      expect(resp[:namespace]).to be(config[:namespace])
      expect(resp[:metric_name]).to be(config[:metric_name])
      expect(resp[:dimensions]).to be(config[:dimensions])
      expect(resp[:period]).to be(config[:period])
      expect(resp[:statistics]).to eq([config[:statistics]])
      expect(resp[:unit]).to be(config[:unit])
      expect((resp[:end_time] - resp[:start_time]).to_i).to be(config[:period] * 10)
    end
  end

  describe '#composite_metrics_request' do
    it 'should return the proper payload' do
      config = {
        namespace: 'namespace',
        dimensions: 'dimensions',
        period: 2,
        statistics: 'stats',
        unit: 'foo'
      }
      @check.config = config
      m = 'metric'
      resp = @check.composite_metrics_request(m)
      expect(resp[:namespace]).to be(config[:namespace])
      expect(resp[:metric_name]).to be(m)
      expect(resp[:dimensions]).to be(config[:dimensions])
      expect(resp[:period]).to be(config[:period])
      expect(resp[:statistics]).to eq([config[:statistics]])
      expect(resp[:unit]).to be(config[:unit])
      expect((resp[:end_time] - resp[:start_time]).to_i).to be(config[:period] * 10)
    end
  end

  describe '#composite_check' do
    before :each do
      Aws.config = { stub_responses: true }
    end

    after :each do
      Aws.config = {}
    end
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
      aws_resp = @check.client.stub_data(:get_metric_statistics)
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered unknown: test could not be retrieved')
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
      aws_resp = @check.client.stub_data(:get_metric_statistics)
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered ok: test returned no data but that\'s ok')
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
      aws_resp = @check.client.stub_data(:get_metric_statistics)
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered ok: denominator_metric_name returned no data but that\'s ok')
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
      aws_resp = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 0.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered unknown: test: denominator value is zero')
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
      aws_resp = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 0.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered ok: test: denominator value is zero but that\'s ok')
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
      aws_resp_num = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 5.to_f])
      aws_resp_den = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 10.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp_num, aws_resp_den)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered critical: test is 50: comparison=less threshold=75')
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
      aws_resp_num = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 5.to_f])
      aws_resp_den = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 10.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp_num, aws_resp_den)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered warning: test is 50: comparison=less threshold=74')
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
      aws_resp_num = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 5.to_f])
      aws_resp_den = @check.client.stub_data(:get_metric_statistics, datapoints: [average: 10.to_f])
      allow(@check).to receive(:get_metric).and_return(aws_resp_num, aws_resp_den)
      allow(@check).to receive(:metric_desc).and_return('test')

      resp = @check.composite_check
      expect(resp).to eq('triggered ok: test is 50: comparison=less, will alarm at 30')
    end
  end
end
