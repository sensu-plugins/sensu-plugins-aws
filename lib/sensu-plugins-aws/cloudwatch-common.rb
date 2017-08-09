
module CloudwatchCommon
  include Common

  def client
    Aws::CloudWatch::Client.new
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

  def composite_metrics_request(config, metric, fixed_time_now = Time.now)
    {
      namespace: config[:namespace],
      metric_name: config[metric],
      dimensions: config[:dimensions],
      start_time: fixed_time_now - config[:period] * 10,
      end_time: fixed_time_now,
      period: config[:period],
      statistics: [config[:statistics]],
      unit: config[:unit]
    }
  end

  def composite_check(config)
    fixed_time_now = Time.now
    numerator_metric_resp = client.get_metric_statistics(composite_metrics_request(config, :numerator_metric_name, fixed_time_now))
    denominator_metric_resp = client.get_metric_statistics(composite_metrics_request(config, :denominator_metric_name, fixed_time_now))

    no_data = resp_has_no_data(numerator_metric_resp, config[:statistics]) || \
              resp_has_no_data(denominator_metric_resp, config[:statistics])
    if no_data && config[:no_data_ok]
      ok "#{metric_desc} returned no data but that's ok"
    elsif no_data && !config[:no_data_ok]
      unknown "#{metric_desc} could not be retrieved"
    end

    denominator_value = read_value(denominator_metric_resp, config[:statistics]).to_f
    if denominator_value.zero?
      ok "#{metric_desc} denominator value is zero but that's ok"
    end
    numerator_value = read_value(numerator_metric_resp, config[:statistics]).to_f
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
