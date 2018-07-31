#!/bin/bash -e 

##This script simply sets the qform back to matching the native space for the mask.

subj=$1
tp=$2
t1=$3

ANTSPATH=/data/grossman/pipedream2018/bin/ants/bin/

antsRT=/data/grossman/pipedream2018/crossSectional/antsct/${subj}/${tp}/

brainQ=`fslhd $t1 | egrep qto | awk '{print $2,$3,$4,$5}' | tr '\n' ' '`
maskQ=`fslhd $antsRT/${subj}_${tp}_BrainExtractionMask.nii.gz | egrep qto | awk '{print $2,$3,$4,$5}' | tr '\n' ' '`

echo $brainQ
echo $maskQ

if [[ $brainQ != $maskQ ]]; then

cmd="${ANTSPATH}CopyImageHeaderInformation $t1 $antsRT/${subj}_${tp}_BrainExtractionMask.nii.gz $antsRT/${subj}_${tp}_BrainExtractionMask.nii.gz 1 1 1"
echo $cmd
$cmd

fi