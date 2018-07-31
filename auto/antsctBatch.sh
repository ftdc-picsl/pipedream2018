#!/bin/bash

# Needed for cron
source /home/mgrossman/.bash_profile

procScriptDir=/data/grossman/pipedream2018/bin/scripts

niiDir=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii
antsctDir=/data/grossman/pipedream2018/crossSectional/antsct

subjectsAndTPs=`${procScriptDir}/auto/findDataToProcess.sh $niiDir $antsctDir`

automatedNotificationEmails=$(perl -e '@emails = `cat /home/mgrossman/pipedream2018Auto/emailAddresses.txt`; chomp @emails; print join(",", @emails);')

echo "Subject,TimePoint" $subjectsAndTPs | tr ' ' '\n' | mail -s "New FTDC T1 data submitted for processing" $automatedNotificationEmails

for stp in $subjectsAndTPs; do
    subject=${stp%,*}
    tp=${stp#*,}
    
    ${procScriptDir}/crossSectional/antsct_single_scan.sh ${subject} ${tp} ${antsctDir} ${scriptsDir}
done
