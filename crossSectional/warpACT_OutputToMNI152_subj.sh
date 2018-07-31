#!/bin/bash

export ANTSPATH=/data/grossman/pipedream2018/bin/ants/bin

templateDir=/data/grossman/pipedream2018/templates/OASIS

if [[ $# -lt 1 ]]; then
cat <<USAGE

  $0 <subject> <timepoint> <outputRootDir>

  subject - subject ID

  timepoint - scan date

  Assumes brain registered to template in $templateDir

  outputRootDir - root directory for output; script creates subject/timepoint subdirectory 

USAGE

exit 1

fi

subj=$1

tp=$2

outputRootDir=$3

outputSpace=normalizedToMNI152/

outputTP_Dir=${outputRootDir}/${subj}/${tp}/

if [[ ! -d $outputTP_Dir ]]; then
  mkdir -p ${outputTP_Dir}
fi

procScriptDir=/data/grossman/pipedream2018/bin/scripts
cmd="qsub -S /bin/bash -cwd -o ${outputTP_Dir}/${subj}_${tp}.stdout -e ${outputTP_Dir}/${subj}_${tp}.stderr ${BinDir}/warpACT_OutputToMNI152_qscript.sh ${procScriptDir}/crossSectional/ ${subj} ${tp} ${outputTP_Dir}/${outputSpace}"

echo $cmd
echo
$cmd
sleep 2
echo
