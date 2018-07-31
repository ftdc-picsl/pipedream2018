#!/bin/bash

if [[ $# -eq 0 ]]; then
  echo \
"
  $0 <subj> <tp> <outputDir>

  Labels T1 image with OASIS labels using pseudo geodesic registration (via group template) of atlases  

" 

exit 1

fi

# Note different ANTs, has antsJointFusion
export ANTSPATH="/data/grossman/pipedream2018/bin/ants/bin/"

subj=$1
tp=$2
outputDir=$3

# Not foolproof but usually works
procScriptDir="/data/grossman/pipedream2018/bin/scripts"
 
antsCT_Dir="/data/grossman/pipedream2018/crossSectional/antsct/"

t1Brain="${antsCT_Dir}/${subj}/${tp}/${subj}_${tp}_ExtractedBrain0N4.nii.gz"

t1BrainMask="${antsCT_Dir}/${subj}/${tp}/${subj}_${tp}_BrainExtractionMask.nii.gz"

templateToT1Warp="${antsCT_Dir}/${subj}/${tp}/${subj}_${tp}_TemplateToSubject0Warp.nii.gz"

templateToT1Affine="${antsCT_Dir}/${subj}/${tp}/${subj}_${tp}_TemplateToSubject1GenericAffine.mat"


${proScriptDir}/crossSectional/pseudoGeodesicJointFusion.pl $t1Brain $t1BrainMask $templateToT1Warp $templateToT1Affine ${outputDir} ${subj}_${tp}_
