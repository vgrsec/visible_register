#!/bin/bash

UNSIGNEDCSVFILE=./csv/ApplicationUsage-Unsigned.csv
SIGNEDCSVFILE=./csv/ApplicationUsage-Signed.csv

clear
#Detect if running as root/sudo
#This is needed to generate the pkg file that will be used to deploy
#the Santa rules database.
if (( EUID != 0 )); then
    echo "You must be root to do this." 1>&2
    exit 1
fi

#Prompt the user to ensure they've staged the correct files
echo 'This script requires that CSVs have been staged in ./csv/*'
echo 'For more details see README'

[[ -f $UNSIGNEDCSVFILE ]] && UNSIGNEDCSV="1" || UNSIGNEDCSV="0"
[[ -f $SIGNEDCSVFILE ]] && SIGNEDCSV="1" || SIGNEDCSV="0"

if [ ${UNSIGNEDCSV} = "1"]; then
while true
do
  cat $UNSIGNEDCSVFILE
  read -p "Unsigned csv appear uploaded is this the correct file (y/n, y to continue)" yn
  case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "Please read README.md and stage ApplicationUsage-Signed.csv in ./csv/. Then rerun step-2-santaconfigbuilder.sh"; exit 1;;
      * ) echo "Please answer y or n.";;
  esac
done
fi
clear
if [ ${SIGNEDCSV} = "1"]; then
while true
do
  cat ~/csv/ApplicationUsage-Signed.csv
  read -p "Signed csv appear uploaded  is this the correct file (y/n, y to continue)" yn
  case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "Please read README.md and stage ApplicationUsage-Signed.csv in ./csv/. Then rerun step-2-santaconfigbuilder.sh"; exit 1;;
      * ) echo "Please answer y or n.";;
  esac
done
fi
clear
if [ ${UNSIGNEDCSV} = "0"]; then
while true
do
  read -p "No Unsigned csv staged is this correct (y/n, y to continue)" yn
  case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "Please stage ApplicationUsage-Unsigned.csv from ElasticSearch in ./csv/ and rerun step-2-santaconfigbuilder.sh"; exit 1;;
      * ) echo "Please answer y or n.";;
  esac
done
fi

if [ ${SIGNEDCSV} = "0"]; then
while true
do
  read -p "No Signed csv staged is this correct (y/n, y to continue)" yn
  case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "Please stage ApplicationUsage-Signed.csv from ElasticSearch in ./csv/ and rerun step-2-santaconfigbuilder.sh"; exit 1;;
      * ) echo "Please answer y or n.";;
  esac
done
fi
clear
echo "Prerequesite check complete"
echo "Extract SHAs from CSV"

#This Code Block parses the csv exported from ElasticSearch

##1. Removes everything between " "
##2. Removes the first comma
##3. Take the 64 characters to the left of the second comma (this is the SHA256 value) and writes it to a file to be parsed later into the Santa DB
#4. Remove the tailing comma 
#5. Remove all duplicate SHAs


echo "Extract SHAs from CSV"

cp $SIGNEDCSVFILE.orig $SIGNEDCSVFILE
sed 's/"[^"]*"//' $SIGNEDCSVFILE > ./tmp/ApplicationUsage-Signed.tmp
sed 's/,//' ./tmp/ApplicationUsage-Signed.tmp > ./tmp/ApplicationUsage-Signed-2.tmp
grep -o '................................................................,' ./tmp/ApplicationUsage-Signed-2.tmp > ./tmp/ApplicationUsage-Signed-3.tmp
sed 's/,//' ./tmp/ApplicationUsage-Signed-3.tmp > ./tmp/ApplicationUsage-Signed-4.tmp

###
#Insert a duplicate sha check here
###

#Stage the file to be processed into the Santa rules database
mv ./tmp/ApplicationUsage-Signed-4.tmp ./macos-santa/ApplicationUsage-Signed-sha256.txt

cp $UNSIGNEDCSVFILE.orig $UNSIGNEDCSVFILE
sed 's/"[^"]*"//' $UNSIGNEDCSVFILE > ./tmp/ApplicationUsage-Unsigned.tmp
sed 's/,//' ./tmp/ApplicationUsage-Unsigned.tmp > ./tmp/ApplicationUsage-Unsigned-2.tmp
grep -o '................................................................,' ./tmp/ApplicationUsage-Unsigned-2.tmp > ./tmp/ApplicationUsage-UnSigned-3.tmp
sed 's/,//' ./tmp/ApplicationUsage-Unsigned-3.tmp > ./tmp/ApplicationUsage-Unsigned-4.tmp
mv ./tmp/ApplicationUsage-Unsigned-4.tmp ./macos-santa/ApplicationUsage-Unsigned-sha256.txt

echo "Write SHAs to rules file"

#This creates the sql file from the Santa default. The only allowed application is
#Apple signed binaries. This is required to allow the operating system to work.
rm ./macos-santa/rules.sql
cp ./macos-santa/rules.sql.orig ./macos-santa/rules.sql

#Remove the Apple Cert from the import CSV. This prevents duplicate records from being created.
sed -i -e 's/"Software Signing",2aa4b9973b7ba07add447ee4da8b5337c3ee2c3a991911e80e7282e8a751fc32,"678,638"//g' ./csv/ApplicationUsage-Signed.csv 
rm ./csv/ApplicationUsage-Signed.csv-e
# Anatomy of a SQL Statement for santa
# INSERT INTO rules VALUES('SHA256',1 = Allow || 2 = Deny, 1 = Application SHA || 2 = Certificate SHA, NULL);

#MacOS SED is bugged, this was how I got to success on this
#https://stackoverflow.com/a/24751341
#https://superuser.com/a/434333

while read SHA256; do
sed '/2aa4b9973b7ba07add447ee4da8b5337c3ee2c3a991911e80e7282e8a751fc32/ a\
  INSERT INTO rules VALUES('"'"''"$SHA256"''"'"',1,1,NULL); \
  ' ./macos-santa/rules.sql > ./macos-santa/rules.tmp && mv ./macos-santa/rules.tmp ./macos-santa/rules.sql
done <./macos-santa/ApplicationUsage-Unsigned-sha256.txt

while read CERT_SHA256; do
sed '/2aa4b9973b7ba07add447ee4da8b5337c3ee2c3a991911e80e7282e8a751fc32/ a\
  INSERT INTO rules VALUES('"'"''"$CERT_SHA256"''"'"',1,2,NULL); \
  ' ./macos-santa/rules.sql > ./macos-santa/rules.tmp && mv ./macos-santa/rules.tmp ./macos-santa/rules.sql
done <./macos-santa/ApplicationUsage-Signed-sha256.txt

echo "Convert sql to squlite database"

#This converts the rules file into the santa rules database.

cat ./macos-santa/rules.sql | sqlite3 ./macos-santa/rules-step-2.db

#This generates the package that is used to deploy the santa rules database
#on to endpoints

echo "Generate pkg to install new rules db on endpoints"

mkdir -p ./tmp/santadb/ROOT/private/var/db/santa/
cp ./macos-santa/rules-step-2.db ./tmp/santadb/ROOT/private/var/db/santa/rules.db
sudo chown -R root:wheel ./tmp/santadb/
pkgbuild --root ./tmp/santadb/ROOT --identifier com.vgrsec.santadb-step-2 --version 1.0 ./santadb-step-2.pkg

#Remove temp files
rm -r ./tmp/*
