#!/bin/bash

# Warps output images from subject space to MNI152 via the Penn template 

if [[ $# -lt 3 ]]; then
  echo " 
 
    $0 <subject> <timepoint> <input> <output> <input> <output> ...

    where <input> is any image in the T1 subject space
  "

  exit 1

fi 

# LATEST ANTSPATH
ANTSPATH=/data/grossman/pipedream2018/bin/ants/bin/

ANTSCT_FILE_PREFIX=$1

shift 1

# T1 to template warps from antsct output

T1_TEMPLATE_WARP=${ANTSCT_FILE_PREFIX}SubjectToTemplate1Warp.nii.gz

T1_TEMPLATE_AFFINE=${ANTSCT_FILE_PREFIX}SubjectToTemplate0GenericAffine.mat

# MNI template and warp
echo "FIX THE TEMPLATE AND WARPS" 

MNI152_TEMPLATE=/data/grossman/pipedream2018/templates/OASIS/MNI152/MNI152_T1_1mm_brain.nii.gz

MNI152_TEMPLATE_WARP=/data/grossman/pipedream2018/templates/OASIS/MNI152/T_template0_ToMNI1521InverseWarp.nii.gz

MNI152_TEMPLATE_AFFINE="/data/grossman/pipedream2018/templates/OASIS/MNI152/T_template0_ToMNI1520GenericAffine.mat"


while [[ $# -gt 0 ]]; do

  inputImage=$1
  outputImage=$2

  shift 2

  if [[ ! -f $inputImage ]]; then
    echo "Input file does not exist: $inputFile"
    exit 1
  fi

  if [[ -z $outputImage ]]; then
    echo "Missing output file for input: $inputFile"
    exit 1
  fi
    
  cmd="${ANTSPATH}antsApplyTransforms -d 3 -i $inputImage -r $MNI152_TEMPLATE -t $MNI152_TEMPLATE_WARP -t $MNI152_TEMPLATE_AFFINE -t $T1_TEMPLATE_WARP -t $T1_TEMPLATE_AFFINE  -o $outputImage"

  echo $cmd
  $cmd

done
