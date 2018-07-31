#!/bin/bash

if [[ $# -lt 1 ]]; then
cat <<USAGE

  $0 <base dir> <processing dir>

  Assuming a subject/timepoint directory structure in both; looks for data points existing
  in base dir but NOT in processing dir. It's a dumb but general way of checking for new
  data.

  Outputs CSV list of subjects and time points to process eg

  123456,20140101
  123456,20150101
  ...

USAGE

exit 1

fi

baseDir=$1

processingDir=$2

if [[ ! -d "$baseDir" ]]; then
  echo " Can't find $baseDir "
  exit 1
fi

if [[ ! -d "$processingDir" ]]; then
  echo " Can't find $processingDir "
  exit 1
fi

# Search for INDDIDs only
subjects=`ls $baseDir | grep -P "^[0-9]{6}(.[0-9]{2})?$"`

for subject in $subjects; do

  # Dates only
  tps=`ls ${baseDir}/${subject} | grep -P "^[0-9]{8}$"`

  for tp in $tps; do
    if [[ ! -d "${processingDir}/${subject}/${tp}" ]]; then
      echo "${subject},${tp}"
    fi
  done

done
