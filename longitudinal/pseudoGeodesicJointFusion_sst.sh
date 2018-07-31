#!/bin/bash

if [[ $# -lt 2 ]]; then
  echo \
"
  $0 <subj> <longDir>

  Labels T1 image with OASIS labels using pseudo geodesic registration (via group template) of atlases  

" 

exit 1

fi

# Note different ANTs, has antsJointFusion
export ANTSPATH="/data/grossman/pipedream2018/bin/ants/bin/"

subj=$1
longDir=$2

outputDir=${longDir}/${subj}/${subj}_SingleSubjectTemplate/

# Not foolproof but usually works
scriptDir=`dirname $0`

sstRoot="${outputDir}/T_template"

sstBrain="${sstRoot}BrainExtractionBrain.nii.gz"

sstBrainMask="${sstRoot}BrainExtractionMask.nii.gz"

templateToT1Warp="${sstRoot}TemplateToSubject0Warp.nii.gz"

templateToT1Affine="${sstRoot}TemplateToSubject1GenericAffine.mat"

${scriptDir}/pseudoGeodesicJointFusion.pl $sstBrain $sstBrainMask $templateToT1Warp $templateToT1Affine ${outputDir} T_template

${scriptDir}/pseudoGeodesicSSTtoTimepoints.sh ${subj} ${longDir} ${outputDir}/T_templatePG_antsLabelFusionLabels.nii.gz
