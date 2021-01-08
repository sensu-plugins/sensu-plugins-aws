# Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed [here](https://github.com/sensu-plugins/community/blob/master/HOW_WE_CHANGELOG.md)

## [Unreleased]

## 18.6.0
### Added
- `check-subnet-ip-consumption.rb` - Added `--warn-only` option (@ChrisCalavera)
- new `metrics-reservation-utilization.rb`: retrieve metrics about reserved instances usage. (@boutetnico)
- `check-ebs-burst-limit.rb`: add `--tag`/`-t` option to specify a volume tag to output in status message. (@boutetnico)
- check-instance-events.rb: re-instate assume-role functionality (@pmiles)
- new `check-expiring-reservations.rb`: check instance reservations and warn about upcoming expiration. (@boutetnico)
- check-cloudwatch-alarm-multi.rb: Add check that will raise a critical if one of cloud watch alarms are in given state, and a critical for each alarm in given state. (@stevenayers)
- `check-cloudwatch-alarms.rb`: `--name-prefix`/`-p` option added to filter alarm names by a prefix. (@boutetnico)

### Fixed
- `check-sqs-messages.rb`: properly surface false positives when pulling an unsupported metric (@majormoses)
- - Prevent the retrieval of all db instances when the `db_cluster_id` option is specified and the `db_instance_id` option is not specified
- updated `.bonsai.yml` to match with other plugins (CentOS6/8 support, etc.) (@nixwiz)

## [18.5.0] - 2020-01-28
### Changed
- `check-trustedadvisor-service-limits.rb`: Trusted Advisor combined Service Limits check ID 'eW7HH0l7J9' scheduled to be disabled on Feb 15 2020. Updated the script to go through every Service Limits checks and look for not 'ok' status. Outcome is the same. (@swibowo)
- bumped version of `bundler` when installing to match travis, before installing dep ensure we have a required version of bundler for development (@majormoses)

## [18.4.2] - 2019-09-23
### Fixed
- Properly parse `--db-cluster-id` option in `check-rds.rb` (@rwha)


## [18.4.1] - 2019-08-21
### Security
- force newer version of nokogiri to address CVE-2019-5477 (@majormoses)

## [18.4.0] - 2019-05-08
### Added
- `check-ebs-burst-limit.rb`: `--filter` option added to filter which volume to check. (@boutetnico)

## [18.3.0] - 2019-05-07
### Added
- Travis build automation to generate Sensu Asset tarballs that can be used in conjunction with Sensu provided ruby runtime assets and the Bonsai Asset Index

## [18.2.0] - 2019-05-06
### Added
- check-rds.rb: added support for new `t3` and `r5` family  instances (@mmitucha)

## [18.1.0] - 2019-05-06
### Added
- `check-ec2-cpu_balance.rb`: `--filter` option added to filter which instance to check. (@boutetnico)

## [18.0.0] - 2019-04-2
### Breaking Changes
- `check-alb-target-group-health.rb` will now alert if a n ALB has no health targets (@kunal-plivo)
- removed ruby `< 2.3` support (@majormoses)
- bump `sensu-plugin` dependency from `~> 2.0` to `~> 4.0` you can read the changelog entries for [4.0](https://github.com/sensu-plugins/sensu-plugin/blob/master/CHANGELOG.md#400---2018-02-17) and [3.0](https://github.com/sensu-plugins/sensu-plugin/blob/master/CHANGELOG.md#300---2018-12-04) (@majormoses)

## [17.2.0] - 2019-04-02
### Added
- `check-rds-pending.rb`: adding option `--db-instance-identifier` to support checking only a single db instance for pending maintenance events, instead of all instances in a region. (@mattdoller)

## [17.1.0] - 2019-04-02
### Changed
- `metrics-cloudfront.rb` now accepts multiple metrics. (@boutetnico)
- `lib/cloudwatch-common.rb` now accepts percentile stats. (@rajiv)


## [17.0.0] - 2019-03-26
### Breaking Changes
- `metrics-cloudfront.rb` `--metric` option was renamed to `--metrics`. (@boutetnico)

### Added
- `check-sqs-messages.rb`: adding option `--exclude-queues` for use in blacklisting specific queues in conjunction with `--prefix` flag. (@ruke47)

### Changed
- `metrics-cloudfront.rb` now accepts multiple metrics. (@boutetnico)

## [16.2.0] - 2019-02-19
### Fixed
- removed codeclimate (@tmonk42)
- properly iterate over IPs in check-vpc-nameservers.rb (@masneyb)

### Added
- `check-ec2-cpu_balance.rb`: adding option `--instance-families` to manage which instance families to check. (@cyrilgdn)

## [16.1.0] - 2018-11-02
### Changed
- updated dev depenency of `github-markup` to `~> 3.0` (@dependabot) (@majormoses)
- updated dev depenency of `rake` to `~> 12.3` (@dependabot) (@majormoses)
- updated dev depenency of `code-climate` to `~> 1.0` (@dependabot) (@majormoses)

## [16.0.0] - 2018-11-02
### Breaking Change
- removed `asw-sdk-v1` as all assets have been upgraded to `aws-sdk-v2` this is technically not a breaking change but for safety reasons in case we missed anything we are versioning it as a major bump (@majormoses)

## [15.0.0] - 2018-11-01
### Breaking Changes
- `check-elb-latency.rb` no longer takes `aws_access_key` and `aws_secret_access_key` options. (@boutetnico)
 ### Changed
- `check-elb-latency.rb` was updated to aws-sdk v2. (@boutetnico)

## [14.0.0] - 2018-11-01
### Breaking Changes
- `check-elb-sum-requests.rb` no longer takes `aws_access_key` and `aws_secret_access_key` options. (@boutetnico)

### Changed
- `check-elb-sum-requests.rb` was updated to aws-sdk v2. (@boutetnico)

## [13.0.0] - 2018-11-01
### Breaking Changes
- `check-redshift-events.rb` no longer takes `aws_access_key` and `aws_secret_access_key` options. (@boutetnico)

### Changed
- `check-redshift-events.rb` was updated to aws-sdk v2. (@boutetnico)

## [12.4.0] - 2018-10-03
### Changed
- check-rds.rb: Updated list of RDS instance types and their respective memory allowance (@swibowo)

## [12.3.0] - 2018-09-25
### Added
- check-s3-objects.rb: Allow check to run against the newest of multiple matching objects (@akatch)

## [12.2.0] - 2018-09-14
### Added
- Add `check-direct-connect-virtual-interfaces.rb` to check the status of Direct Connect virtual interfaces

## [12.1.0] - 2018-08-28
### Added
- new `check-efs.rb`: checks cloudwatch metrics with the efs namespace for an arbitrary metric (@ivanfetch)

## [12.0.0] - 2018-06-21
### Breaking Changes
- `check-ebs-burst-limit.rb`: Fixed period to pass to config from 60 to 120 so as to not have empty values returned sometimes (@wari)

## [11.6.0] - 2018-06-21
### Added
- metrics-rds.rb: adding option `--fetch-age` to allow getting metrics in the past (@multani)

## [11.5.1] - 2018-06-21
### Fixed
- check-rds-pending: Fix issue if there are no RDS instances in a region. Previously this would raise an API exception (@stevenviola)

## [11.5.0] - 2018-05-17
### Added
- handler-ses.rb: can now set `mail_to` in a check and handler will send to the appropriate email (@Juan-Moreno)

## [11.4.2] - 2018-05-10
### Fixed
- Handle case where a prefix is used and no objects are found. (@akatch)

## [11.4.1] - 2018-05-07
### Fixed
- Trim all leading whitespace from each line in the email bodies when using the SES handler, and not a specific number of spaces, which may change as files are reformatted/refactored. (@mattdoller)

## [11.4.0] - 2018-04-28
### Security
- updated yard dependency to `~> 0.9.11` per: https://nvd.nist.gov/vuln/detail/CVE-2017-17042 (@yuri-zubov sponsored by Actility, https://www.actility.com)

### Added
- Added ability to get metrics from WAF (@yuri-zubov sponsored by Actility, https://www.actility.com)

## [11.3.1] - 2018-04-17
### Fixed
- check-rds-events.rb: fixed issues with queries because the assume local time, now we force UTC timezone (@nadarashwin) (@majormoses)

## [11.3.0] - 2018-03-22
### Added
- Added ability to get metrics from cloudfront (@yuri-zubov sponsored by Actility, https://www.actility.com)

## [11.2.0] - 2018-11-22
### Added
- check-s3-bucket-visibility.rb: option `--exclude-regex-filter` to allow using regex to filter out undesired buckets from the results (@majormoses)

### Fixed
- check-s3-bucket-visibility.rb: fixed `nilClass` error when `--exlcuded-buckets` was not provided by returning false if its nil (@majormoses)

## [11.1.0] - 2018-11-21
### Added
- check-s3-bucket-visibility.rb: added option `--all-buckets` to check for all buckets in the region specified for insecure buckets (@majormoses)
- check-s3-bucket-visibility.rb: added option `--excluded-buckets` to ignore specific buckets that are expected to be loose such as s3 buckets for static website hosting (@majormoses)

### Changed
- check-s3-bucket-visibility.rb: now uses `aws-sdk-s3` while keeping other plugins locked at their respective versions (@majormoses)

## [11.0.0] - 2018-02-09
### Breaking Changes
- metrics-elb-full.rb: removed in favor of metrics-elb.rb, which is slightly more configurable and uses the AWS-SDK v2 already. Compared to metrics-elb-full.rb, metrics-elb.rb no longer takes --aws-access-key, --aws-secret-access-key flags, Authentication should be configured per [here](https://github.com/sensu-plugins/sensu-plugins-aws/blob/master/README.md#authentication). --scheme has a default value of `elb` now (@multani)
- metrics-elb.rb: honors the --fetch_age flag which now looks up values 60 seconds in the past by default. This was the intended behavior, as documented in the NOTES section (@multani)
- metrics-elb.rb: --scheme default value is `elb` now, to be more consistent with the other metrics checks (@multani)

### Fixed
- metrics-elb.rb: properly handle the --scheme and --fetch_age flags (@multani)

## [10.2.0] - 2018-01-20
### Added
- `check-s3-bucket-visiblity.rb` - checks an S3 bucket for existence of a website configuration or bucket policy containing `Get*`,
`List*` or `*` statements. (@rhussmann)

## [10.1.2] - 2018-01-13
### Security
- updated rubocop dependency to `~> 0.51.0` per: https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2017-8418. (@majormoses)

### Changed
- appease the new cops where it required light refactoring, called out TODO's for later refactoring (@majormoses)

## [10.1.1.] - 2018-01-13
### Fixed
- check-instance-health.rb: fixed incorrect test operator from `&&` to `||` in `gather_events`, should reject if either case is true. (@randeffects)

## [10.1.0] - 2018-01-06
- check-cloudwatch-composite-metric.rb: add flags `zero_denominator_data_ok`, `no_denominator_data_ok`, and `numerator_default` to add ability to allow numerator in composite to be 0. While leaving the functionality of `no_data_ok` the same, this change allows us to check to alert if the numerator has no data since 0/X is a valid alert case. (@zbintliff)
- lib/cloudwatch-common.rb: added tests for majority of functions (@zbintliff)


## [10.0.3] - 2017-12-03
### Fixed
- metrics-asg.rb: fix dimension name, handle the --scheme flag, make the --statistic flag work, support autoscaling groups containing spaces in their name (@multani)

## [10.0.2] - 2017-12-02
### Fixed
- check-beanstalk-elb-metric.rb, check-cloudwatch-metric.rb, check-cloudwatch-composite-metric.rb: fixed incorrect help message (@arthurlogilab)

## [10.0.1] - 2017-11-18
### Added
- check-rds.rb: Add R4 instances (@enokawa)

## [10.0.0] - 2017-10-24
### Breaking Changes
- handler-ses.rb, handler-sns.rb: Update to AWS-SDK v2. With the update to AWS-SDK v2 these handlers no longer take `access_key`, `secret_key`, or `use_ami_role` settings. Authentication should be configured per [here](https://github.com/sensu-plugins/sensu-plugins-aws/blob/master/README.md#authentication). (@eheydrick)

### Changed
- Update to `aws-sdk` 2.10 (@eheydrick)

## [9.0.1] - 2017-10-17
### Fixed
- metrics-billing.rb: replace `-s` with `-S` for services definition to prevent conflict with scheme option (@boutetnico)

## [9.0.0] - 2017-10-16
### Breaking Changes
- metrics-sqs.rb, check-elb-certs.rb, check-elb-nodes.rb, check-elb-health-sdk.rb, metrics-ec2-count.rb: Update to AWS-SDK v2.
  With the update to SDK v2 these checks no longer take `aws_access_key` and `aws_secret_access_key` options.
  Credentials should be set in a credential file or with an IAM instance profile.
  See the [auth section](https://github.com/sensu-plugins/sensu-plugins-aws/blob/master/README.md#authentication) of the README for
  details on setting credentials. (@eheydrick)

## [8.3.1] - 2017-10-12
### Fixed
- check-eni-status.rb: fixed `ok` message to be correct (@damiendurant)
- check-eni-status.rb: made it executable after merge (@majormoses)

### Changed
- updated changelog guideline location (@majormoses)

## [8.3.0] - 2017-09-16
### Added
- check-ec2-cpu_balance.rb: Add option `--tag`/`-t` to add a specified instace tag (e.g. instace name) to message. (@snadorp)

## [8.2.0] - 2017-09-05
### Added
- metrics-rds.rb: adding option `--scheme` to allow changing the default scheme (@julio-ogury)

## [8.1.0] - 2017-08-28
### Fixed
check-ebs-burst-limit.rb: Only compare the warning threshold if a `-w` option was specified on the command-line, as usage shows `-w` is optional. (@ivanfetch)

### Added
- check-ebs-burst-limit.rb: Only check volumes attached to the current instance with a new `-s` option, which also overrides the `-r` option for EC2 region. (@ivanfetch)

## [8.0.0] - 2017-08-20
### Breaking Changes
- check-beanstalk-elb-metric.rb and check-cloudwatch-metric.rb: `--opertor` flag was a typo, please use `--operator` now. (@guikcd)

## [7.1.0] - 2017-08-14
### Added
- Add `check-alb-target-group-health.rb` that checks the health of ALB target groups (@eheydrick)

## [7.0.1] - 2017-08-12
### Fixed
- check-cloudwatch-metric.rb, check-cloudwatch-composite-metric.rb: fixed defaults to work (@majormoses)
- check-cloudwatch-metric.rb: short option `-n` was conflicting with `no_data_ok` and `namespace` as `check-cloudwatch-composite-metric.rb` uses `-O` I opted for that for consistency (@majormoses)

### Changed
- check-cloudwatch-metric.rb, check-cloudwatch-composite-metric.rb: `self.parse_dimensions` and `dimension_string` were the same in both checks. This fix was common among both checks so I moved it into the module

## [7.0.0] - 2017-08-07
### Breaking Change
- Bump min dependency on `sensu-plugin` to 2.x (@huynt1979)

## [6.3.0] - 2017-07-13
### Added
- add check-cloudwatch-alarms.rb (@obazoud)

## [6.2.0] - 2017-07-07
### Added
- check-ec2-filter.rb: add --min-running-secs flag for specifying
  minimum number of seconds an instance should be running before it is
  included in the instance count. (@cwjohnston)

## [6.1.1] - 2017-07-07
### Added
- ruby 2.4 testing (@majormoses)

### Changed
- misc repo fixes (@majormoses)

### Fixed
- check-asg-instances-created check fails due to int and string comparison

## [6.1.0] - 2017-06-23
### Added
- check-eni-status.rb: new check to monitor the status of one or more ENI

## [6.0.1] - 2017-05-11
### Fixed
- check-instance-events.rb: fix instance Name tag retrieval that broke upon aws sdk v2 update, and update output message handling (@swibowo)

## [6.0.0] - 2017-05-10
### Breaking Change
- check-elb-nodes.rb returns critical instead of unknown if total number of nodes equals zero (@autarchprinceps)

## [5.1.0] - 2017-05-09
- check-s3-object.rb: Add an option to check a file by his prefix (@julio-ogury)

## [5.0.0] - 2017-05-03
### Breaking Change
- removed check_vpc_vpn.py as it is broken and not worth fixing when `check-vpc-vpn.rb` is the direction forward. (@majormoses)

### Fixed
- check-instance-health.rb now supports checking more than 100 instances (aws api limit) by batching into multiple requests if needed. (@majormoses)
- check-elb-fog.rb set the variable name fog expects (@majormoses)

## [4.1.0] - 2017-05-01
###  Added
- check-cloudwatch-composite-metric.rb: Allow calculation of percentage for cloudwatch metrics  by composing two metrics (@cornelf) (numerator_metric/denominator_metric * 100) as a percentage. This is useful to skip pushing such metrics to graphite in order to get the percentage metric computed.
- check-cloudwatch-composite-metric.rb: protect against zero division errors (@cornelf)
- check-sqs-messages.rb now supports specifying multiple queues wihtout a prefix (@majormoses)
- check-asg-instances-created.rb is a new check that allows looking at the number od instances created in the last hour (@phoppe93)

### Changed
- check-sns-subscriptions.rb improved error messages (@obazoud)

### Fixed
- lib/sensu-plugins-aws/cloudwatch-common.rb use the most recent datapoint (@mivok)


## [4.0.0] - 2016-12-27
### Breaking Changes
- `check-sqs-messages.rb`, `check-vpc-vpn.rb`, and `metrics-elb.rb` were updated to aws-sdk v2 and no longer take `aws_access_key` and `aws_secret_access_key` options.
  Credentials should be set in environment variables, a credential file, or with an IAM instance profile.
  See http://docs.aws.amazon.com/sdkforruby/api/#Configuration for details on setting credentials

### Added
- check-cloudwatch-alarm.rb: Add region support (@ptqa)
- metrics-s3.rb: added (@obazoud)
- metrics-billing.rb: added (@obazoud)
- add check-cloudfront-tag.rb and check-s3-tag.rb (@obazoud)
- check-s3-object.rb: add an option to check s3 object's size (@obazoud)
- check-ebs-burst-limit.rb: added (@nyxcharon)
- check-sqs-messages.rb: added support for checking different metric types (@majormoses)
- check-rds.rb: Support added for Aurora Clusters (@daanemanz)
- check-vpc-vpn.rb: added warning/critical flags (@bootswithdefer)
- add check-route53-domain-expiration.rb that checks when domains registered in Route53 are close to expiration (@eheydrick)
- check-ec2-filter.rb: Add exclude tags option (@obazoud)
- add metrics-rds.rb (@phoppe93)
- check-instance-health.rb: Add support for filters (@AlexKulbiy)
- check-rds.rb: Support added for checking all databases in a region (@sstarcher)
- check-ecs-service-health.rb: Add `primary_status` option to limit checks to primary deployments (@matthew-watson1)
- Add check-asg-instances-created.rb to check for recent autoscaling events (@phoppe93)
- Add check-asg-instances-inservice.rb to check autoscaling group size (@phoppe93)
- Add check-elb-instances-inservice.rb to check service status of ELB instances (@phoppe93)
- Add metrics-asg.rb to grab metrics from autoscaling groups (@phoppe93)

### Fixed
- check-ses-limits.rb: Fix percentage calculation (@eheydrick)
- check-ec2-cpu_balance.rb: fix warning and critical message (@mool)
- check-instance-events.rb: fixed missing events code; instance-reboot (@TorPeeto)
- check-instances-count.rb: fixed issues related to aws sdk version bump (@majormoses)
- metrics-elb-full.rb: Fix output (@obazoud)
- Fix cloudwatch imports (@nyxcharon)

### Changed
- check-sqs-messages.rb: upgrade to aws-sdk v2 (@majormoses)
- check-vpc-vpn: upgrade to aws-sdk v2 (@phoppe93)
- check-instance-events.rb: migrated the script to aws sdk v2 because of incompatibility of sdk v1 with newer regions (@oba11)
- check-rds-events.rb: migrated the script to aws sdk v2 because of incompatibility of sdk v1 with newer regions (@oba11)
- metrics-autoscaling-instance-count.rb: migrated the script to aws sdk v2 and support fetching all autoscaling groups (@oba11)
- metrics-elb.rb: upgrade to aws-sdk v2 (@phoppe93)

## [3.2.1] - 2016-08-10
### Fixed
- check-instance-health.rb: fixed remediated events not working after resolving it (@oba11)
- Fixed bugs in check-emr-steps.rb (@babsher)
- check-elb-certs.rb: Fix error introduced by rubocop cleanup (#125 @eheydrick)

## [3.2.0] - 2016-08-03
### Fixed
- metrics-emr-steps.rb: fixed typo in variable name (@babsher)
- metrics-sqs.rb: --scheme option now works with --prefix (@mool)
- check-ecs-service-health.rb:
  - `service_list` retrieves all records when services not provided through options (@marckysharky)
  - `service_details` - handles scenario whereby services array is greater than aws limit (10) (@marckysharky)
- exit code for tests did not respect rspec exit codes due to autorun feature. (#133 @zbintliff)
- syntax error in check-sensu-clients (@sstarcher)
- check-rds-pending: Fix uninitialized constant (@obazoud)

### Added
- check-rds.rb: Add support for assuming a role in another account (@oba11)
- check-instance-events.rb: Add instance_id option (@Jeppesen-io)
- check-sensu-clients.rb: SSL support (@sstarcher)
- common.rb: adding support for environment variable AWS_REGION when region is specified as an empty string (@sstarcher)
- metrics-sqs.rb: Add support for recording additional per-queue SQS metrics (counts of not-visible and delayed messages) (@paddycarey)
- check-subnet-ip-consumption.rb: to check consumption of IP addresses in subnets and alert if consumption exceeds a threshold (@nickjacques)
- check-beanstalk-health.rb: Add optional region support
- check-rds-events.rb: Added '-r all' region support (@swibowo)
- check-instance-events.rb: Added '-r all' region support and description of the event. Minor change to output message (@swibowo)
- check-elb-health-sdk.rb: Updated available regions fetch (@swibowo)
- handler-ec2_node.rb: Add region support (@runningman84)

### Changed
- Update `aws-sdk` dependency pin to ~> 2.3 (@sstarcher)

## [3.1.0] - 2016-05-15
### Fixed
- check-instance-events.rb: Ignore completed instance-stop ec2 events
- check-instance-events.rb: Ignore canceled system-maintenance ec2 events

## Added
- Added check-instance-reachability.rb: looks up all instances from a filter set and pings
- Added check-route.rb: checks a route to an instance / eni on a route table
- Added check-rds-pending.rb: checks for pending RDS maintenance events

### Changed
- handler-ec2_node.rb updated to allow configuration set from client config
- metrics-ec2-filter.rb: Moved filter parsing to library
- update to Rubocop 0.40 and cleanup

## [3.0.0] - 2016-05-05
### Removed
- Support for Ruby 2.0

### Added
- Support for Ruby 2.3
- check-elb-health-sdk.rb: Added multi-region support and specify instance tag to display on check output
- check-rds.rb: Added check for IOPS

## [2.4.3] - 2016-04-13
### Fixed
- check-ses-statistics.rb: fix variable

## [2.4.2] - 2016-04-13
### Fixed
- check-ses-statistics.rb, check-emr-steps.rb: fix requires
- check-ses-statistics.rb, metrics-ses.rb: sort results from SES

## [2.4.1] - 2016-04-13
### Fixed
- check-ses-statistics.rb: Make sure inputs are integers

## [2.4.0] - 2016-04-13
### Added
- Added metrics-ses.rb to collect SES metrics from GetSendStatistics
- Added check-ses-statistics.rb to check SES thresholds from GetSendStatistics
- check-emr-steps.rb: Added options to check different step status for check EMR steps
- metrics-emr.rb: Added cluster ID to EMR step metrics
- Added two handlers for increasing/decreasing desired capacity of autoscaling groups
- Implemented check for reserved instances
- Added check to ensure that some or all AWS ConfigService rules have full compliance
- Added check to ensure that SNS subscriptions is not pending
- handler-ec2_node.rb: protect from instance state_reason which may be nil
- Added check to ensure that some or all ECS Services are healthy on a cluster
- Added check to ensure a KMS key is available (enabled or disabled)
- metrics-elasticache.rb: retrieve BytesUsedForCache metric for redis nodes

## [2.3.0] - 2016-03-18
### Added
- Implemented metrics for EMR cluster steps
- Implemented check for EMR cluster failed steps

### Changed
- Update to aws-sdk 2.2.28

### Fixed
- check-cloudwatch-metric.rb: removed invalid .length.empty? check

## [2.2.0] - 2016-02-25
### Added
- check-ebs-snapshots.rb: added -i flag to ignore volumes with an IGNORE_BACKUP tag
- check-sensu-client.rb Ensures that ec2 instances are registered with Sensu.
- check-trustedadvisor-service-limits.rb: New check for service limits based on Trusted Advisor API
- check-sqs-messages.rb,metrics-sqs.rb: Allow specifying queues by prefix with -p option
- check-rds-events.rb: Add option to check a specific RDS instance
- Add plugin check-elasticache-failover.rb that checks if an Elasticache node is in the primary state

### Fixed
- metrics-elasticache.rb: Gather node metrics when requested

## [2.1.1] - 2016-02-05
### Added
- check-ec2-cpu_balance.rb: scans for any t2 instances that are below a certain threshold of cpu credits
- check-instance-health.rb: adding ec2 instance health and event data

### Changed
- Update to aws-sdk 2.2.11 and aws-sdk-v1 1.66.0

### Fixed
- check-vpc-vpn.rb: fix execution error by running with aws-sdk-v1
- handler-ec2_node.rb: default values for ec2_states were ignored
- added new certs

## [2.1.0] - 2016-01-15
### Added
- check-elb-health-sdk.rb: add option for warning instead of critical when unhealthy instances are found
- check-rds.rb: add M4 instances
- handler-sns.rb: add option to use a template to render body mail
- check-rds-events.rb: add RDS event message to output
- Added check-cloudwatch-metric that checks the values of cloudwatch metrics
- Added check-beanstalk-elb-metric that checks an ELB used in a Beanstalk environment
- Added check-certificate-expiry that checks the expiration date of certificates loaded into IAM
- Added test cases for check-certificate-expiry.rb

### Changed
- handler-ec2_node.rb: Update to new API event naming and simplifying ec2_node_should_be_deleted method and fixing match that will work with any user state defined, also improved docs
- metrics-elb-full.rb: flush hash in-between iterations
- check-ses-limit.rb: move to AWS-SDK v2, use common module, return unknown on empty responses

### Fixed
- metrics-memcached.rb: Fixed default scheme
- Fix typo in cloudwatch comparison check

## [2.0.1] - 2015-11-03
### Changed
- pinned all dependencies
- set gemspec to require > `2.0.0`

Nothing new added, this is functionally identical to `2.0.0`. Doing a github release which for some reason failed even though a gem was built and pushed.

## [2.0.0] - 2015-11-02

WARNING: This release drops support for Ruby 1.9.3, which is EOL as of 2015-02.

### Added
- Added check-cloudwatch-alarm to get alarm status
- Added connection metric for check-rds.rb
- Added check-s3-bucket that checks S3 bucket existence
- Added check-s3-object that checks S3 object existence
- Added check-emr-cluster that checks EMR cluster existence
- Added check-vpc-vpn that checks the health of VPC VPN connections

### Fixed
- handler-ec2_node checks for state_reason being nil prior to code access
- Cosmetic fixes to metrics-elb, check-rds, and check-rds-events
- Return correct metrics values in check-elb-sum-requests

### Removed
- Removed Ruby 1.9.3 support

## [1.2.0] - 2015-08-04
### Added
- Added check-ec2-filter to compare filter results to given thresholds
- Added check-vpc-nameservers, which given a VPC will validate the name servers in the DHCP option set.

### Fixed
- handler-ec2_node accounts for an empty instances array

## [1.1.0] - 2015-07-24
### Added
- Added new AWS SES handler - handler-ses.rb
- Add metrics-ec2-filter to store node ids and count matching a given filter
- Check to alert on unlisted EIPs

## [1.0.0] - 2015-07-22

WARNING:  This release contains major breaking changes that will impact all users.  The flags used for access key and secret key have been standardized accross all plugins resulting in changed flags for the majority of plugins. The new flags are -a AWS_ACCESS_KEY and -k AWS_SECRET_KEY.

### Added
- EC2 node handler will now remove nodes terminated by a user
- Transitioned EC2 node handler from fog to aws sdk v2
- Allowed ignoring nil values returned from Cloudwatch in the check-rds plugin. Previously if Cloudwatch fell behind you would be alerted
- Added support for checking multiple ELB instances at once by passing a comma separated list of ELB instance names in metrics-elb-full.rb
- Added check-autoscaling-cpucredits.rb for checking T2 instances in autoscaling groups that are running low on CPU credits
- Updated the fog and aws-sdk gems to the latest versions to improve performance, reduce 3rd party gem dependencies, and add support for newer AWS features.
- Add metrics-ec2-filter to store node ids and count matching a given filter

### Fixed
- Renamed autoscaling-instance-count-metrics.rb -> metrics-autoscaling-instance-count.rb to match our naming scheme
- Reworked check-rds-events.rb to avoid the ABCSize warning from rubocop
- Corrected the list of plugins / files in the readme
- Make ELB name a required flag for the metrics ELB plugins to prevent nil class errors when it isn't provided
- Properly document that all plugins default to us-east-1 unless the region flag is passed
- Fix the ELB metrics plugins to properly use the passed auth data
- Fixed the metrics-elb-full plugin to still add the ELB instance name when a graphite schema is appended
- Fixed all plugins to support passing the AWS access and secret keys from shell variables. Plugin help listed this as an option for all plugins, but the support wasn't actually there.

## [0.0.4] - 2015-07-05
### Added
- Added the ability to alert on un-snapshotted ebs volumes

## [0.0.3] - 2015-06-26
### Fixed
- Access key and secret key should be optional
- Added 3XX metric collection to the ELB metrics plugins
- Fixed the metric type for SurgeQueueLength ELB metrics
- Fixed logic for ec2 instance event inclusion

## [0.0.2] - 2015-06-02
### Fixed
- added binstubs

### Changed
- removed cruft from /lib

## 0.0.1 - 2015-05-21
### Added
- initial release

[Unreleased]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.6.0...HEAD
[18.6.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.5.0...18.6.0
[18.5.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.4.2...18.5.0
[18.4.2]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.4.1...18.4.2
[18.4.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.4.0...18.4.1
[18.4.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.3.0...18.4.0
[18.3.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.2.0...18.3.0
[18.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.1.0...18.2.0
[18.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/18.0.0...18.1.0
[18.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/17.2.0...18.0.0
[17.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/17.1.0...17.2.0
[17.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/17.0.0...17.1.0
[17.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/16.2.0...17.0.0
[16.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/16.1.0...16.2.0
[16.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/16.0.0...16.1.0
[16.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/15.0.0...16.0.0
[15.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/14.0.0...15.0.0
[14.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/13.0.0...14.0.0
[13.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/12.4.0...13.0.0
[12.4.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/12.3.0...12.4.0
[12.3.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/12.2.0...12.3.0
[12.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/12.1.0...12.2.0
[12.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/12.0.0...12.1.0
[12.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.6.0...12.0.0
[11.6.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.5.1...11.6.0
[11.5.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.5.0...11.5.1
[11.5.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.4.2...11.5.0
[11.4.2]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.4.1...11.4.2
[11.4.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.4.0...11.4.1
[11.4.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.3.1...11.4.0
[11.3.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.3.0...11.3.1
[11.3.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.2.0...11.3.0
[11.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.1.0...11.2.0
[11.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/11.0.0...11.1.0
[11.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.2.0...11.0.0
[10.2.0]:https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.1.2...10.2.0
[10.1.2]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.1.1...10.1.2
[10.1.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.1.0...10.1.1
[10.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.1.0...10.0.3
[10.0.3]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.0.2...10.0.3
[10.0.2]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.0.1...10.0.2
[10.0.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/10.0.0...10.0.1
[10.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/9.0.1...10.0.0
[9.0.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/9.0.0...9.0.1
[9.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/8.3.1...9.0.0
[8.3.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/8.3.0...8.3.1
[8.3.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/8.2.0...8.3.0
[8.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/8.1.0...8.2.0
[8.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/8.0.0...8.1.0
[8.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/7.1.0...8.0.0
[7.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/7.0.1...7.1.0
[7.0.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/7.0.0...7.0.1
[7.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/6.3.0...7.0.0
[6.3.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/6.2.0...6.3.0
[6.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/6.1.1...6.2.0
[6.1.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/6.1.0...6.1.1
[6.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/6.0.1...6.1.0
[6.0.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/6.0.0...6.0.1
[6.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/5.1.0...6.0.0
[5.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/5.0.0...5.1.0
[5.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/4.1.0...5.0.0
[4.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/4.0.0...4.1.0
[4.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/3.2.1...4.0.0
[3.2.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/3.2.0...3.2.1
[3.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/3.1.0...3.2.0
[3.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/3.0.0...3.1.0
[3.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.4.3...3.0.0
[2.4.3]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.4.2...2.4.3
[2.4.2]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.4.1...2.4.2
[2.4.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.4.0...2.4.1
[2.4.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.3.0...2.4.0
[2.3.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.2.0...2.3.0
[2.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/v2.1.1...2.2.0
[2.1.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.1.0...v2.1.1
[2.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.0.1...2.1.0
[2.0.1]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/2.0.0...2.0.1
[2.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/1.2.0...2.0.0
[1.2.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/0.0.4...1.0.0
[0.0.4]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/0.0.3...0.0.4
[0.0.3]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/0.0.2...0.0.3
[0.0.2]: https://github.com/sensu-plugins/sensu-plugins-aws/compare/0.0.1...0.0.2
