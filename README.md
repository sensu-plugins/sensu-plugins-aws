## Sensu-Plugins-aws

[![Build Status](https://travis-ci.org/sensu-plugins/sensu-plugins-aws.svg?branch=master)](https://travis-ci.org/sensu-plugins/sensu-plugins-aws)
[![Gem Version](https://badge.fury.io/rb/sensu-plugins-aws.svg)](http://badge.fury.io/rb/sensu-plugins-aws)
[![Code Climate](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws/badges/gpa.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws)
[![Test Coverage](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws/badges/coverage.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-aws)
[![Dependency Status](https://gemnasium.com/sensu-plugins/sensu-plugins-aws.svg)](https://gemnasium.com/sensu-plugins/sensu-plugins-aws)
[![Codeship Status for sensu-plugins/sensu-plugins-aws](https://codeship.com/projects/2a9c6e70-d4b4-0132-67ee-4e043b6b23b5/status?branch=master)](https://codeship.com/projects/77866)

## Functionality

**check-autoscaling-cpucredits.rb**

**check-cloudwatch-alarm**

**check-dynamodb-capacity.rb**

**check-dynamodb-throttle.rb**

**check-ebs-snapshots.rb**

**check-ec2-filter.rb**

**check-ec2-network.rb**

**check-eip-allocation.rb**

**check-elb-certs.rb**

**check-elb-health-fog.rb**

**check-elb-health-sdk.rb**

**check-elb-health.rb**

**check-elb-latency.rb**

**check-elb-nodes.rb**

**check-elb-sum-requests.rb**

**check-emr-cluster.rb**

**check-instance-events.rb**

**check-rds-events.rb**

**check-rds.rb**

**check-redshift-events.rb**

**check-s3-bucket.rb**

**check-s3-object.rb**

**check-ses-limit.rb**

**check-sqs-messages.rb**

**check-vpc-nameservers**

**check_vpc_vpn.py**

**handler-ec2_node.rb**

**handler-ses.rb**

**handler-sns.rb**

**metrics-autoscaling-instance-count.rb**

**metrics-ec2-count.rb**

**metrics-ec2-filter.rb**

**metrics-elasticache.rb**

**metrics-elb-full.rb**

**metrics-elb.rb**

**metrics-sqs.rb**


## Files

* /bin/check-autoscaling-cpucredits.rb
* /bin/check-cloudwatch-alarm.rb
* /bin/check-dynamodb-capacity.rb
* /bin/check-dynamodb-throttle.rb
* /bin/check-ebs-snapshots.rb
* /bin/check-ec2-filter.rb
* /bin/check-ec2-network.rb
* /bin/check-elb-certs.rb
* /bin/check-elb-health-fog.rb
* /bin/check-elb-health-sdk.rb
* /bin/check-elb-health.rb
* /bin/check-elb-latency.rb
* /bin/check-elb-nodes.rb
* /bin/check-elb-sum-requests.rb
* /bin/check-emr-cluster.rb
* /bin/check-instance-events.rb
* /bin/check-rds-events.rb
* /bin/check-rds.rb
* /bin/check-redshift-events.rb
* /bin/check-s3-object.rb
* /bin/check-ses-limit.rb
* /bin/check-sqs-messages.rb
* /bin/check-vpc-nameservers.rb
* /bin/check_vpc_vpn.py
* /bin/handler-ec2_node.rb
* /bin/handler-ses.rb
* /bin/handler-sns.rb
* /bin/metrics-autoscaling-instance-count.rb
* /bin/metrics-ec2-count.rb
* /bin/metrics-ec2-filter.rb
* /bin/metrics-elasticache.rb
* /bin/metrics-elb-full.rb
* /bin/metrics-elb.rb
* /bin/metrics-sqs.rb

## Usage

**handler-ses**
```
{
  "ses": {
    "mail_from": "sensu@example.com",
    "mail_to": "monitor@example.com",
    "use_ami_role": true,
    "access_key": "myaccesskey",
    "secret_key": "mysecretkey",
    "region": "us-east-1",
    "subscriptions": {
      "subscription_name": {
        "mail_to": "teamemail@example.com"
      }
    }
  }
}
```

**handler-sns**
```
{
  "sns": {
    "topic_arn": "arn:aws:sns:us-east-1:111111111111:topic",
    "use_ami_role": true,
    "access_key": "MY_KEY",
    "secret_key": "MY_secret"
  }
}
```
## Installation

[Installation and Setup](http://sensu-plugins.io/docs/installation_instructions.html)

Note:  In addition to the standard installation requirements the installation of this gem will require compiling the nokogiri gem.  Due to this you'll need certain developmemnt packages on your system.  On Ubuntu systems install build-essential, libxml2-dev and zlib1g-dev.  On CentOS install gcc and zlib-devel.
