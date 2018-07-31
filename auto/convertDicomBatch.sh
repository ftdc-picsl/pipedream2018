#!/bin/bash

source /home/mgrossman/.bash_profile

procScriptDir=/data/grossman/pipedream2018/bin/scripts

dicomDir=/data/jet/grosspeople/Volumetric/SIEMENS/Subjects
niiDir=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii

subjectsAndTPs=`${procScriptDir}/auto/findDataToProcess.sh $dicomDir $niiDir`

for stp in $subjectsAndTPs; do
  subject=${stp%,*}
  tp=${stp#*,}

  qsub -S /bin/bash  -l h_vmem=2.1G,s_vmem=2G  -o ${subject}_${tp}_dicom2niiAuto.stdout -e  ${subject}_${tp}_dicom2niiAuto.stderr ${procScriptDir}/auto/convertDicom.sh $subject $tp

  sleep 0.5

done
