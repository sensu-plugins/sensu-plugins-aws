
module CloudwatchCommon
  include Common

  def aws_config
    {
      access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def client(opts = {})
    config = aws_config.merge(opts)
    @client ||= Aws::CloudWatch::Client.new config
  end

  def read_value(resp, stats)
    resp.datapoints.sort_by(&:timestamp).last.send(stats.downcase)
  end

  def resp_has_no_data(resp, stats)
    resp.datapoints.nil? || resp.datapoints.empty? || resp.datapoints.first.nil? || read_value(resp, stats).nil?
  end

  def compare(value, threshold, compare_method)
    case compare_method
    when 'greater'
      value > threshold
    when 'less'
      value < threshold
    when 'not'
      value != threshold
    else
      value == threshold
    end
  end

  def metrics_request(config)
    {
      namespace: config[:namespace],
      metric_name: config[:metric_name],
      dimensions: config[:dimensions],
      start_time: Time.now - config[:period] * 10,
      end_time: Time.now,
      period: config[:period],
      statistics: [config[:statistics]],
      unit: config[:unit]
    }
  end

  def get_metric(metric)
    client.get_metric_statistics(composite_metrics_request(metric))
  end

  def composite_metrics_request(metric)
    ## config is a class variable but don't want to change signature
    metrics_request(config).merge(metric_name: metric)
  end

  def composite_check
    numerator_metric_resp = get_metric(config[:numerator_metric_name])
    denominator_metric_resp = get_metric(config[:denominator_metric_name])

    no_data = resp_has_no_data(denominator_metric_resp, config[:statistics])
    if no_data && config[:no_denominator_data_ok]
      ok "#{config[:denominator_metric_name]} returned no data but that's ok"
    elsif no_data && !config[:no_denominator_data_ok]
      unknown "#{config[:denominator_metric_name]} could not be retrieved"
    end

    denominator_value = read_value(denominator_metric_resp, config[:statistics]).to_f
    if denominator_value.zero?
      ok "#{metric_desc} denominator value is zero but that's ok"
    end

    ## Only use found metric if there is one else go to the default.
    numerator_value = resp_has_no_data(numerator_metric_resp, config[:statistics]) ? config[:numerator_default] : read_value(numerator_metric_resp, config[:statistics]).to_f
    value = (numerator_value / denominator_value * 100).to_i
    base_msg = "#{metric_desc} is #{value}: comparison=#{config[:compare]}"

    if compare(value, config[:critical], config[:compare])
      critical "#{base_msg} threshold=#{config[:critical]}"
    elsif config[:warning] && compare(value, config[:warning], config[:compare])
      warning "#{base_msg} threshold=#{config[:warning]}"
    else
      ok "#{base_msg}, will alarm at #{!config[:warning].nil? ? config[:warning] : config[:critical]}"
    end
  end

  def self.parse_dimensions(dimension_string)
    dimension_string.split(',')
                    .collect { |d| d.split '=' }
                    .collect { |a| { name: a[0], value: a[1] } }
  end

  def dimension_string
    config[:dimensions].map { |d| "#{d[:name]}=#{d[:value]}" }.join('&')
  end

  def check(config)
    resp = client.get_metric_statistics(metrics_request(config))

    no_data = resp_has_no_data(resp, config[:statistics])
    if no_data && config[:no_data_ok]
      ok "#{metric_desc} returned no data but that's ok"
    elsif no_data && !config[:no_data_ok]
      unknown "#{metric_desc} could not be retrieved"
    end

    value = read_value(resp, config[:statistics])
    base_msg = "#{metric_desc} is #{value}: comparison=#{config[:compare]}"

    if compare value, config[:critical], config[:compare]
      critical "#{base_msg} threshold=#{config[:critical]}"
    elsif config[:warning] && compare(value, config[:warning], config[:compare])
      warning "#{base_msg} threshold=#{config[:warning]}"
    else
      ok "#{base_msg}, will alarm at #{!config[:warning].nil? ? config[:warning] : config[:critical]}"
    end
  end
end
