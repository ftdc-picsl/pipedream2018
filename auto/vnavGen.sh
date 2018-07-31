#!/bin/bash

if [[ $# -lt 2 ]]; then
cat <<USAGE

  $0 <subject> <timepoint>  
  
  subject - individual's INDDID

  timepoint - cluster formatted date (YYYYMMDD)

USAGE

exit 1

fi

subject=$1
tp=$2

outputDir=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii/${subject}/${tp}/rawNii/
tmpDir=${outputDir}/${subject}_${tp}_tmp/
scriptDir=/data/grossman/tools/vnav/parse_vNav_Motion-master/
dicomDir=/data/jet/grosspeople/Volumetric/SIEMENS/Subjects/${subject}/${tp}
outfile=${outputDir}/${subject}_${tp}_vnav.csv

vnav=`ls -d ${dicomDir}/*vNav*passive | tail -1`

if [[ -d $vnav ]]; then 

mkdir -p ${tmpDir} 

moco=`ls -d ${dicomDir}/*vNav_moco | head -1`
pass=`ls -d ${dicomDir}/*vNav_passive | head -1`

cp -r $moco $tmpDir
cp -r $pass $tmpDir
chmod -R u+w $tmpDir
gunzip -rf $tmpDir

tmpMoco=`ls -d ${tmpDir}/*moco/`
tmpPass=`ls -d ${tmpDir}/*passive/`


echo "INDDID,TIMEPOINT,rmsMoco,rmsPass,maxMoco,maxPass" > $outfile

    rmsMoco=`/share/apps/python/Python-2.7.9/bin/python2.7 ${scriptDir}/parse_vNav_Motion.py --input ${tmpMoco}/* --tr 2.4 --rms`
    rmsPass=`/share/apps/python/Python-2.7.9/bin/python2.7 ${scriptDir}/parse_vNav_Motion.py --input ${tmpPass}/* --tr 2.4 --rms`
    maxMoco=`/share/apps/python/Python-2.7.9/bin/python2.7 ${scriptDir}/parse_vNav_Motion.py --input ${tmpMoco}/* --tr 2.4 --max`
    maxPass=`/share/apps/python/Python-2.7.9/bin/python2.7 ${scriptDir}/parse_vNav_Motion.py --input ${tmpPass}/* --tr 2.4 --max`


echo ${subject}","${tp}","${rmsMoco}","${rmsPass}","${maxMoco}","${maxPass} >> $outfile

rm -rf $tmpDir

else

exit 1

fi