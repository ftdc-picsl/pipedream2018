#!/bin/bash

source /home/mgrossman/.bash_profile

procScriptDir=/data/grossman/pipedream2018/bin/scripts

dtScriptDir=${procScriptDir}/crossSectional/dti

niiDir=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii

dtOutDir=/data/grossman/pipedream2018/crossSectional/dti/

antsCTDir=/data/grossman/pipedream2018/crossSectional/antsct

# Collect subjects and TPs that get processed
processingList=""

logDate=`date +%Y_%m_%d`

logFile="dtSubmissionLog_${logDate}.txt"

for subject in `ls $niiDir`; do
  for tp in `ls ${niiDir}/$subject`; do 

    if [[ -f "${antsCTDir}/${subject}/${tp}/${subject}_${tp}_ACTStage6Complete.txt" && -d ${niiDir}/${subject}/${tp}/DWI && ! -d ${dtOutDir}/${subject}/${tp}/connMat ]]; then
      scriptToRun=/tmp/dtNorm_${subject}_${tp}.sh

      echo "#!/bin/bash
${dtScriptDir}/processDTI.pl --subject $subject --timepoints $tp --qsub 0
${dtScriptDir}/dtConnMatSubj.pl --subject $subject --timepoints $tp --antsct-base-dir $antsCTDir --dt-base-dir $dtOutDir --qsub 0
mv ${dtOutDir}/${subject}/${tp}/connMat/connMat_${subject}_${tp}_log.txt ${dtOutDir}/${subject}/${tp}/logs
mv ${dtOutDir}/${subject}/${tp}/connMat/connMat_${subject}_${tp}.sh ${dtOutDir}/${subject}/${tp}/scripts
" > $scriptToRun

      echo "--- qsub output for $subject ${tp} ---" >> $logFile

      qsub -S /bin/bash -l h_vmem=8G,s_vmem=8G -pe unihost 2 -binding linear:2 -e /dev/null -o /dev/null $scriptToRun >> $logFile 2>&1

      echo "---" >> $logFile

      sleep 0.1

      processingList="$processingList ${subject},${tp}"

    fi

  done
done

automatedNotificationEmails=$(perl -e '@emails = `cat /home/mgrossman/pipedream2018Auto/emailAddresses.txt`; chomp @emails; print join(",", @emails);')

echo "Subject,TimePoint" $processingList | tr ' ' '\n' | mail -s "New FTDC DTI data submitted for processing" $automatedNotificationEmails

