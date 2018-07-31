#!/bin/bash

dicomDir=/data/jet/grosspeople/Volumetric/SIEMENS/Subjects

if [[ $# -lt 1 ]]; then
cat <<USAGE

  $0 <subject> <timepoint> 
  
  subject - subject ID
  timepoint - scan date

  Script looks for data in $dicomDir

  Calls dicom2nii, then sets up T1 / DWI links

USAGE

exit 1

fi

subject=$1
tp=$2

vnavScript=/data/grossman/pipedream2018/scripts/
baseDir=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/


niiOutDir=${baseDir}/subjectsNii/${subject}/${tp}/rawNii

scriptDir=${baseDir}/scripts

${baseDir}/bin/pipedream/dicom2nii/dicom2nii.sh $dicomDir $subject $tp ${baseDir}/lists/protocolsToConvert.txt $niiOutDir

${scriptDir}/linkT1.pl $subject $tp
${scriptDir}/linkDWI.pl $subject $tp

${vnavScript}/vnavGen.sh $subject $tp

# Permissions
chmod -R g+w ${baseDir}/subjectsNii/${subject}/${tp}

