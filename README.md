## Sensu-Plugins-aws

[![Build Status](https://travis-ci.org/sensu-plugins/sensu-plugins-aws.svg?branch=master)](https://travis-ci.org/sensu-plugins/sensu-plugins-aws)
[![Gem Version](https://badge.fury.io/rb/sensu-plugins-aws.svg)](http://badge.fury.io/rb/sensu-plugins-aws)
[![Code Climate](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws/badges/gpa.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws)
[![Test Coverage](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws/badges/coverage.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws)
[![Dependency Status](https://gemnasium.com/sensu-plugins/sensu-plugins-aws.svg)](https://gemnasium.com/sensu-plugins/sensu-plugins-aws)
[ ![Codeship Status for sensu-plugins/sensu-plugins-aws](https://codeship.com/projects/2a9c6e70-d4b4-0132-67ee-4e043b6b23b5/status?branch=master)](https://codeship.com/projects/77866)

## Functionality

**check_vpc_vpn**

**autoscaling-instance-count-metrics.rb**

**check-dynamodb-capacity.rb**

**check-dynamodb-throttle.rb**

**check-ec2-network.rb**

**check-elb-certs.rb**

**check-elb-health-fog.rb**

**check-elb-health-sdk.rb**

**check-elb-latency.rb**

**check-elb-nodes.rb**

**check-elb-sum-requests.rb**

**check-instance-events.rb**

**check-rds-events.rb**

**check-rds.rb**

**check-redshift-events.rb**

**check-ses-limit.rb**

**check-sqs-messages.rb**

**ec2-count-metrics.rb**

**ec2-node.rb**

**elasticache-metrics.rb**

**elb-full-metrics.rb**

**elb-latency-metrics.rb**

**elb-metrics.rb**

**sqs-metrics.rb**

## Files

* /bin/check_vpc_vpn
* /bin/autoscaling-instance-count-metrics.rb
* /bin/check-dynamodb-capacity.rb
* /bin/check-dynamodb-throttle.rb
* /bin/check-ec2-network.rb
* /bin/check-elb-certs.rb
* /bin/check-elb-health-fog.rb
* /bin/check-elb-health-sdk.rb
* /bin/check-elb-latency.rb
* /bin/check-elb-nodes.rb
* /bin/check-elb-sum-requests.rb
* /bin/check-instance-events.rb
* /bin/check-rds-events.rb
* /bin/check-rds.rb
* /bin/check-redshift-events.rb
* /bin/check-ses-limit.rb
* /bin/check-sqs-messages.rb
* /bin/metrics-ec2-count.rb
* /bin/handler-ec2-node.rb
* /bin/metrics-elasticache.rb
* /bin/metrics-elb-full.rb
* /bin/metrics-elb-latency.rb
* /bin/metrics-elb.rb
* /bin/metrics-sqs.rb

## Usage

**handler-sns**
```
{
  "sns": {
    "topic_arn": "arn:aws:sns:us-east-1:111111111111:topic"
    ,"use_ami_role": true
    ,"access_key": "MY_KEY"
    ,"secret_key": "MY_secret"
  }
}
```
## Installation

[Installation and Setup](https://github.com/sensu-plugins/documentation/blob/master/user_docs/installation_instructions.md)

## Notes
