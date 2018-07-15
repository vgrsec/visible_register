# MacOS

## Tools

  * Google Santa
    * Google built open source application whitelisting tool for MacOS.
  * FluentD
    * FluentD provides log collecting and shipping. This was chosen because it can be installed and configured without installing tools like Xcode, MacPorts, or Homebrew.
  * AWS CloudWatch Logs
    * This is the initial log repository. It serves as a security boundary allowing endpoints to log 24/7/365 from anywhere, transporting logs over SSL using an unprivileged IAM account.
  * AWS Lambda
    * AWS Lambda provides connection from AWS CloudWatch Logs to ElasticSearch
  * AWS ElasticSearch
    * AWS ElasticSearch provides log processing, metrics, and reporting capabilities. This can be replaced with non AWS ElasticSearch solutions with a minimal amount of code.

## Step 0 - Setup
  * Run `step-0-awssetup.sh` to build the cloud infrastructure.
    0. Asks for AWS Admin Credentials to function
    0. Asks what region to build endpoint monitoring environment
    0. Logs region for CloudWatch Logs in clientsetup.sh
    0. Creates endpointlogger IAM user
    0. Logs AccessKey and AccessSecretKey for endpointlogger in clientsetup.sh Creates IAM policy to restrict endpointlogger to single CloudWatch Log Group, in a region.
    0. Creates CloudWatch Log Group in region
    0. Creates Lambda Function to use santaingest rule
    0. Creates ElasticSearch 6.2 instance
    0. Configures ElasticSearch with ingest rule and dashboards

  * Run `step-0-clientsetup.sh` to configure an endpoint to log to the AWS infrastructure
    0. Downloads fluentd and Google Santa
    0. Installs fluentd and Google Santa
    0. Configures td-agent.conf to log Google Santa logs to AWS Downloads Google Santa
```
Be aware that with MacOS 10.13.4 Kernel Hooks need to be approved by a user upon installation.

If you use a MacOS configuration manager make sure you enable Google Santa's KEXT.

https://grahamgilbert.com/blog/2017/09/11/enabling-kernel-extensions-in-high-sierra/
https://www.jamf.com/jamf-nation/discussions/27653/summary-of-macos-10-13-4-information-and-links
```

    0. Configures Google Santa to Audit
    0. Stops and Starts Santa and Fluentd launchd services.

## Step 1 - Monitor
No scripts here, human intelligence required. Make sure your endpoints are reporting in by looking at the AWS Log Group (each host gets their own stream by hostname). Watch the AWS ElasticSearch Step 1 Monitor dashboard for anomalies that should be investigated.

## Step 2 - Audit (not done)

* Download Signed & Unsigned CSVs from AWS ElasticSearch Step 2 Audit dashboard.
* In an editor (Microsoft Excel, Google Sheets, VIM, Emacs, Notepad, Atom, etc) remove all rows that should be denied
* Save CSVs (with the same name as downloaded)
* Place modified CSVs (with the same name) in the `.\csv` directory
* Run `step-2-santainitialdbbuilder.sh`


## Step 3 - Baseline (not done)
Deploy santa.db to endpoints (this contains all approved apps from Step 2 - Audit) Review AWS ElasticSearch Step 3 Baseline dashboard for denies. Ensure all denies are expected.
If update of santa.db is required download AWS ElasticSearch Step 3 Baseline csv and run step-3-santaconfigupdater.sh to approve binaries missed in Step 2 and redeploy santa.db

## Step 4 - Enforce (not done)
Run step-4-santaconfigupdater.sh to generate santa.conf in enforce mode to deploy to enterprise.
Continuously Monitor AWS ElasticSearch Enforcement Denies


https://blog.trailofbits.com/2018/05/29/manage-santa-within-osquery/amp/