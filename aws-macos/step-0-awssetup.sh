#!/bin/bash

clear
#Detect if running as root/sudo
if (( EUID != 0 )); then
    echo "You must be root to do this." 1>&2
    exit 1
fi

CURRENTUSER=$(stat -f %Su "/dev/console")
CURRENTUSERGROUP=$(id -g -n $CURRENTUSER)
TIMESTAMP=`date '+%Y%m%dT%H%M%S'`
WANIP=$(curl -s http://whatismyip.akamai.com/)

#Detect if AWS Tools are installed

AWSTOOLSDIR="/usr/local/aws/bin"
AWSTOOLSINSTALLED="0"

if [[ -d "${AWSTOOLSDIR}" && ! -L "${AWSTOOLSDIR}" ]] ; then
    AWSTOOLSINSTALLED="1"
fi

#Ask if reinstallation of AWS Tools is desired

if [ ${AWSTOOLSINSTALLED} = "1" ]; then
while true
do
  read -p "AWS Tools are installed do you wish to reinstall? (y/n) " yn
  case $yn in
      [Yy]* ) AWSTOOLSINSTALLED="0"; break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
  esac
done
fi

#Install AWS Tools

if [ ${AWSTOOLSINSTALLED} = "0" ]; then
  echo "Install AWS Tools"
  curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
  unzip awscli-bundle.zip
  ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
  AWSTOOLSINSTALLED="1"
fi

#Check and set AWS Admin credentials and Configuration

[[ -f ~/.aws/credentials ]] && AWSCREDSSET="1" || AWSCREDSSET="0"

if [ ${AWSCREDSSET} = "1" ]; then
while true
do
  cat ~/.aws/credentials
  read -p "AWS access credentials are already set do you need to reset them? " yn
  case $yn in
      [Yy]* ) AWSCREDSSET="0"; break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
  esac
done
fi

[[ -f ~/.aws/config ]] && AWSCONFIGSSET="1" || AWSCONFIGSSET="0"

if [ ${AWSCONFIGSSET} = "1" ]; then
while true
do
  cat ~/.aws/config
  read -p "AWS configuration is already set do you need to reset them? " yn
  case $yn in
      [Yy]* ) AWSCONFIGSSET="0"; break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
  esac
done
fi

if [ ${AWSCREDSSET} = "0" ]; then
  mv ~/.aws/credentials ~/.aws/credentials.$TIMESTAMP
  echo "Enter your AWS IAM admin Access Key ID"
  read adminawsaccesskey
  aws configure set aws_access_key_id $adminawsaccesskey

  echo "Enter your AWS IAM admin Secret Key"
  read adminawssecretkey
  aws configure set aws_secret_access_key $adminawssecretkey

  cat ~/.aws/credentials

  chown -R $CURRENTUSER:$CURRENTUSERGROUP ~/.aws/
  AWSCREDSSET="1"
fi

if [ ${AWSCONFIGSSET} = "0" ]; then
  mv ~/.aws/config ~/.aws/config.$TIMESTAMP
  echo "Enter the region to build in (ex us-east-2)"
  read AWSREGION
  aws configure set default.region $AWSREGION

  cat ~/.aws/config

  chown -R $CURRENTUSER:$CURRENTUSERGROUP ~/.aws/
  AWSCONFIGSET="1"
fi

AWSREGION=$(aws configure get region)
AWSACCOUNT=$(aws sts get-caller-identity --output text --query 'Account')

echo "Create the IAM user to write to CloudWatch from the endpoint"

#Destroy and Create endpointlogger user
aws iam detach-user-policy --user-name endpointlogger --policy-arn arn:aws:iam::$AWSACCOUNT:policy/endpointloggerpolicy > /dev/null 2>&1
aws iam list-access-keys --user-name endpointlogger > ./tmp/endpointlogger-existing-keys
EXISTING_KEY_ID=$(awk '/.AccessKeyId./{print substr($2,2,length($2)-2)}' ./tmp/endpointlogger-existing-keys)
aws iam delete-access-key --access-key-id $EXISTING_KEY_ID --user-name endpointlogger > /dev/null 2>&1
aws iam delete-user --user-name endpointlogger > /dev/null 2>&1
aws iam create-user --user-name endpointlogger > /dev/null 2>&1
aws iam create-access-key --user-name endpointlogger > ./tmp/endpointlogger.json.tmp

echo "Configure the endpoint installation script"
#Write endpointlogger API Key and Secret to macos-installer.sh
#This is shit code because sed on MacOS doesn't support -P
#also -i may not be used with stdin. Sorry.

#1 Grep for the AccessKeyID & SecretAccessKey of the endpointlogger and write it to a temp file
grep -o '.*"AccessKeyId".*' ./tmp/endpointlogger.json.tmp > ./tmp/AccessKeyId.tmp
grep -o '.*"SecretAccessKey".*' ./tmp/endpointlogger.json.tmp > ./tmp/SecretAccessKey.tmp
#2 Remove all characters that aren't the Access Key
sed -i -e 's/ //g' ./tmp/AccessKeyId.tmp && sed -i -e 's/://g' ./tmp/AccessKeyId.tmp && sed -i -e 's/AccessKeyId//g' ./tmp/AccessKeyId.tmp && sed -i -e 's/"//g' ./tmp/AccessKeyId.tmp && sed -i -e 's/,//g' ./tmp/SecretAccessKey.tmp
sed -i -e 's/ //g' ./tmp/SecretAccessKey.tmp && sed -i -e 's/://g' ./tmp/SecretAccessKey.tmp && sed -i -e 's/SecretAccessKey//g' ./tmp/SecretAccessKey.tmp && sed -i -e 's/"//g' ./tmp/SecretAccessKey.tmp && sed -i -e 's/,//g' ./tmp/SecretAccessKey.tmp
#3 Cat the AccessKeyID to a variable
AWSKEYID=$(cat ./tmp/AccessKeyId.tmp)
AWSSECRETKEY=$(cat ./tmp/SecretAccessKey.tmp)
#4 fix SED Nonssense https://unix.stackexchange.com/posts/255869/revisions
AWSSECRETKEY=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$AWSSECRETKEY")

#Prepare the installer.sh
rm ./macos-installer/installer.sh
cp ./macos-installer/installer.sh.orig ./macos-installer/installer.sh

#Write the variables to the installer.sh
sed -i -e 's/blankaccesskey/'$AWSKEYID'/g' ./macos-installer/installer.sh
sed -i -e 's/blanksecretkey/'$AWSSECRETKEY'/g' ./macos-installer/installer.sh
sed -i -e 's/blankregion/'$AWSREGION'/g' ./macos-installer/installer.sh
rm ./macos-installer/installer.sh-e

#Prepare the fluentd config
rm ./macos-installer/td-agent.conf
cp ./macos-installer/td-agent.conf.orig ./macos-installer/td-agent.conf

#Write the variables to the installer.sh
sed -i -e 's/blankaccesskey/'$AWSKEYID'/g' ./macos-installer/td-agent.conf
sed -i -e 's/blanksecretkey/'$AWSSECRETKEY'/g' ./macos-installer/td-agent.conf
sed -i -e 's/blankregion/'$AWSREGION'/g' ./macos-installer/td-agent.conf
rm ./macos-installer/td-agent.conf-e

echo "Secure the IAM user to only be able to write to CloudWatch logs and do nothing else in AWS"
#Build endpointlogger's policy config
rm ./aws-iam/endpointloggerpolicy.json
cp ./aws-iam/endpointloggerpolicy.json.orig ./aws-iam/endpointloggerpolicy.json
sed -i -e 's/region/'$AWSREGION'/g' ./aws-iam/endpointloggerpolicy.json
sed -i -e 's/account-id/'$AWSACCOUNT'/g' ./aws-iam/endpointloggerpolicy.json
rm ./aws-iam/endpointloggerpolicy.json-e

#Destroy and Create endpointlogger's endpointloggerpolicy.
#The delete will fail if the policy was manipulated by hand, creating multiple
#versions. This isn't accounted for in this script.
aws iam delete-policy --policy-arn arn:aws:iam::$AWSACCOUNT:policy/endpointloggerpolicy > /dev/null 2>&1
aws iam create-policy --policy-name endpointloggerpolicy --policy-document file://./aws-iam/endpointloggerpolicy.json > /dev/null 2>&1
aws iam attach-user-policy --user-name endpointlogger --policy-arn arn:aws:iam::$AWSACCOUNT:policy/endpointloggerpolicy > /dev/null 2>&1

echo "Create roles for AWS ElasticSearch"

#create role config for lambda to ElasticSearch
rm ./aws-iam/lambdaelasticsearchpolicy.json
cp ./aws-iam/lambdaelasticsearchpolicy.json.orig ./aws-iam/lambdaelasticsearchpolicy.json
sed -i -e 's/region/'$AWSREGION'/g' ./aws-iam/lambdaelasticsearchpolicy.json
sed -i -e 's/account-id/'$AWSACCOUNT'/g' ./aws-iam/lambdaelasticsearchpolicy.json
rm ./aws-iam/lambdaelasticsearchpolicy.json-e

#create role for lambda to ElasticSearch
aws iam delete-role-policy --role-name lambda_elasticsearch_execution --policy-name lambdaespolicy  > /dev/null 2>&1
aws iam delete-role --role-name lambda_elasticsearch_execution > /dev/null 2>&1
aws iam create-role --role-name lambda_elasticsearch_execution --assume-role-policy-document file://./aws-iam/lambdaelasticsearchtrust.json.orig > /dev/null 2>&1
aws iam put-role-policy --role-name lambda_elasticsearch_execution --policy-name lambdaespolicy --policy-document file://./aws-iam/lambdaelasticsearchpolicy.json > /dev/null 2>&1
aws iam update-assume-role-policy --role-name lambda_elasticsearch_execution --policy-document file://./aws-iam/lambdaelasticsearchtrust.json.orig > /dev/null 2>&1

echo "Create Cloudwatch log group"
#Destroy amd Create Cloudwatch Log Group

aws logs delete-log-group --log-group-name endpointlogs > /dev/null 2>&1
aws logs create-log-group --log-group-name endpointlogs > /dev/null 2>&1
aws logs put-retention-policy --log-group-name endpointlogs --retention-in-days 7 > /dev/null 2>&1

echo "Create ElasticSearch Instance (this contains 12 minutes worth of sleep to allow for aws processing)"
#Create ElasticSearch DB config
rm ./aws-elasticsearch62/elasticsearchaccesspolicy.json
cp ./aws-elasticsearch62/elasticsearchaccesspolicy.json.orig ./aws-elasticsearch62/elasticsearchaccesspolicy.json
sed -i -e 's/region/'$AWSREGION'/g' ./aws-elasticsearch62/elasticsearchaccesspolicy.json
sed -i -e 's/account-id/'$AWSACCOUNT'/g' ./aws-elasticsearch62/elasticsearchaccesspolicy.json
sed -i -e 's/ipaddress/'$WANIP'/g' ./aws-elasticsearch62/elasticsearchaccesspolicy.json
rm ./aws-elasticsearch62/elasticsearchaccesspolicy.json-e

echo "Deleting old ES domain"
aws es delete-elasticsearch-domain \
    --domain-name endpointlogs > /dev/null 2>&1

#Sleep to let ElasticSearch node to get created
sleep 300

echo "Creating new ES domain"
aws es create-elasticsearch-domain --domain-name endpointlogs \
    --elasticsearch-version 6.2 \
    --elasticsearch-cluster-config InstanceType=m4.large.elasticsearch,InstanceCount=1 \
    --ebs-options EBSEnabled=true,VolumeType=standard,VolumeSize=10 \
    --encryption-at-rest-options Enabled=True \
    --access-policies file://./aws-elasticsearch62/elasticsearchaccesspolicy.json > /dev/null 2>&1

#Sleep to let ElasticSearch node to get created
sleep 600


#Get Elasticsearch endpoint variable
aws es describe-elasticsearch-domain --domain-name endpointlogs > ./aws-elasticsearch62/elasticsearch.json

#1 Grep for the AccessKeyID & SecretAccessKey of the endpointlogger and write it to a temp file
grep -o '.*"Endpoint".*' ./aws-elasticsearch62/elasticsearch.json > ./tmp/Endpoint.tmp
#2 Remove all characters that aren't the Endpoint
sed -i -e 's/ //g' ./tmp/Endpoint.tmp && sed -i -e 's/://g' ./tmp/Endpoint.tmp && sed -i -e 's/Endpoint//g' ./tmp/Endpoint.tmp && sed -i -e 's/"//g' ./tmp/Endpoint.tmp && sed -i -e 's/,//g' ./tmp/Endpoint.tmp
#3 Cat the Endpoint to a variable
ELASTICSEARCHENDPOINT=$(cat ./tmp/Endpoint.tmp)
#4 fix SED Nonssense https://unix.stackexchange.com/posts/255869/revisions
ELASTICSEARCHENDPOINT=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$ELASTICSEARCHENDPOINT")

echo "Create the Lambda function that ties CloudWatch logs to ElasticSearch"

#Modify Lambda function to containe ES endpoint
#This JS is the out of box script provided by Amazon
#except it includes action.index.pipeline = "santalogparsing"

rm ./aws-lambda/index.js > /dev/null 2>&1
rm ./aws-lambda/index.js.zip > /dev/null 2>&1
cp ./aws-lambda/index.js.orig ./aws-lambda/index.js
sed -i -e 's/blankelasticsarchendpoint/'$ELASTICSEARCHENDPOINT'/g' ./aws-lambda/index.js
rm ./aws-lambda/index.js-e
zip -r ./aws-lambda/index.js.zip ./aws-lambda/index.js > /dev/null 2>&1

#Setup ElasticSearch

curl -XPUT "https://$ELASTICSEARCHENDPOINT/_ingest/pipeline/santalogparsing" -H "Content-Type: application/json" -d @./aws-elasticsearch62/santalogparse.json.orig
curl -XPOST "https://$ELASTICSEARCHENDPOINT/cwl-initial/initial?pipeline=santalogparsing" -H "Content-Type: application/json" -d @./aws-elasticsearch62/initiallog.json.orig

#This use to create a default index patern, but sometime after 6.2 it stopped. 
#After 6.2 this would create the kibana index and hose it so one couldn't create
#an index pattern, nor would this one work.
#curl -XPOST "https://$ELASTICSEARCHENDPOINT/.kibana/doc/index-pattern:cwl" -H "Content-Type: application/json" -d @./aws-elasticsearch62/defaultindexpattern.json.orig

curl -XPOST "https://$ELASTICSEARCHENDPOINT/.kibana/doc/visualization:step2appusagesigned" -H 'Content-Type: application/json' -d @./aws-elasticsearch62/visstep2appusagesigned.json.orig
curl -XPOST "https://$ELASTICSEARCHENDPOINT/.kibana/doc/visualization:step2appusageunsigned" -H 'Content-Type: application/json' -d @./aws-elasticsearch62/visstep2appusageunsigned.json.orig

echo $ELASTICSEARCHENDPOINT

#Create Lambda function config file
rm ./aws-lambda/cloudwatchtoelasticsearchpolicy.json > /dev/null 2>&1
cp ./aws-lambda/cloudwatchtoelasticsearchpolicy.json.orig ./aws-lambda/cloudwatchtoelasticsearchpolicy.json
sed -i -e 's/region/'$AWSREGION'/g' ./aws-lambda/cloudwatchtoelasticsearchpolicy.json
sed -i -e 's/account-id/'$AWSACCOUNT'/g' ./aws-lambda/cloudwatchtoelasticsearchpolicy.json
rm ./aws-lambda/cloudwatchtoelasticsearchpolicy.json-e

#Delete the Lambda Function if it exists
aws lambda delete-function --function-name "LogsToElasticsearch_endpointlogs" > /dev/null 2>&1

#Create the Lambda Function and set permissions
aws lambda create-function \
    --function-name "LogsToElasticsearch_endpointlogs" \
    --description "CloudWatch Logs to Amazon ES streaming" \
    --runtime "nodejs4.3" \
    --handler "index.handler" \
    --memory-size "128" \
    --role "arn:aws:iam::$AWSACCOUNT:role/lambda_elasticsearch_execution" \
    --zip-file "fileb://./aws-lambda/index.js.zip" \
    --publish > /dev/null 2>&1

aws lambda add-permission \
    --function-name "LogsToElasticsearch_endpointlogs" \
    --statement-id "1" \
    --principal "logs.$AWSREGION.amazonaws.com" \
    --action "lambda:InvokeFunction" \
    --source-arn "arn:aws:logs:$AWSREGION:$AWSACCOUNT:log-group:endpointlogs:*" \
    --source-account $AWSACCOUNT > /dev/null 2>&1

sleep 30

echo "Create Cloudwatch Logs Subscription Function"

aws logs delete-subscription-filter \
  --log-group-name "endpointlogs" \
  --filter-name "endpointlogstoes" > /dev/null 2>&1

aws logs put-subscription-filter \
    --log-group-name "endpointlogs" \
    --filter-name "endpointlogstoes" \
    --filter-pattern "" \
    --destination-arn "arn:aws:lambda:$AWSREGION:$AWSACCOUNT:function:LogsToElasticsearch_endpointlogs" > /dev/null 2>&1



#Remove temp files

rm -r ./tmp/*


