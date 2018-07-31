#!/bin/bash

if [[ $# -lt 2 ]]; then
cat <<USAGE

  $0 <subjects>  <outputDir> <inputNiftiDirectory>
  
  subjects: List of subject IDs, one per line; AND/OR list of subject IDs and desired timepoints, separated by ","

  outputDir: where you want your output. Probably best to put in /data/grossman/pipedream2018/longitudinal/{your new dir}  

optional argument:

  inputNiftiDirectory: directory containing raw niftis images, organized {id}/{timepoint}/T1/file.nii.gz
                       If left blank, defaults to /data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii/

USAGE

exit 1

fi

subject=$1
outDir=$2
bindir=`dirname $0`
echo $#

if [[ $# -eq 3 ]]; then
  subNiiDir=$3
  echo $subNiiDir
else
  subNiiDir=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii/
fi
echo $subNiiDir
for i in `cat $subject`; do
  subvar=$(echo $i | sed 's/,/ /g')
  counter=$(echo $subvar | awk -F' ' '{ print NF-1 }')
  if [[ ${counter} -gt 0 ]] ; then 
    echo "You specified timepoints ${subvar} " 
    cmd="${bindir}/antsLongCT_WithPriorCookingSubjNii.pl ${outDir} ${subNiiDir} ${subvar}"
  else
    tps=`ls -d --color=none ${subNiiDir}/${subvar}/2*/ | rev | cut -d '/' -f2 | rev `
    echo "No timepoints specified: searching ${subNiiDir}/${subvar}/ for timepoints to process" 
    cmd="${bindir}/antsLongCT_WithPriorCookingSubjNii.pl ${outDir} ${subNiiDir} ${i} ${tps}"
  fi

  echo $cmd
  $cmd
  sleep .5
done

