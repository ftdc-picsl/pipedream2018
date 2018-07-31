#!/bin/sh

subj=$1

# tp=$2

longRootDir=$2

outputSpace=normalizedToMNI152/
antsPath=/data/grossman/pipedream2018/bin/ants/bin/
c3dpath=/share/apps/c3d/c3d-1.1.0-Nightly-2017-04-04/bin/

for tp_Dir in `ls -d --color=none ${longRootDir}/${subj}/${subj}_2*/` ; 
  do 
    tpa=$(echo $tp_Dir | rev | cut -d'/' -f2 | rev)
    tp=$(echo $tpa | cut -d '_' -f2)
    outputDir=${tp_Dir}/normalizedToMNI152/
    if [[ ! -d $outputDir ]]; then
      mkdir -p ${outputDir}
    fi
    ANTSCT_FILE_PREFIX=${tp_Dir}/${subj}_${tp}

# Images to warp
INPUT_DESCRIPTORS=(CorticalThickness GMP)
OUTPUT_DESCRIPTORS=(CorticalThicknessNormalizedToMNI152  GMPNormalizedToMNI152)

SUFFIX=".nii.gz"

if [[ ! -f ${ANTSCT_FILE_PREFIX}_GMP${SUFFIX} ]]; then
  echo "Creating  ${ANTSCT_FILE_PREFIX}_GMP${SUFFIX} "
  ${c3dpath}/c3d ${ANTSCT_FILE_PREFIX}*Posteriors2.nii.gz ${ANTSCT_FILE_PREFIX}*Posteriors4.nii.gz ${ANTSCT_FILE_PREFIX}*Posteriors5.nii.gz -add -add -o ${ANTSCT_FILE_PREFIX}_GMP${SUFFIX}
fi 

if [[ ${#INPUT_DESCRIPTORS[@]} -ne ${#OUTPUT_DESCRIPTORS[@]} ]]; then
  echo "Mapping of input files to output files does not match, exiting"
  exit 1
fi

for (( i = 0; i < ${#INPUT_DESCRIPTORS[@]}; i++ )); do
  echo "  ${INPUT_DESCRIPTORS[$i]} -> ${OUTPUT_DESCRIPTORS[$i]}"
done

# T1 to SST warps from antsLongCT output
T1_TEMPLATE_WARP=${ANTSCT_FILE_PREFIX}*SubjectToTemplate1Warp.nii.gz

T1_TEMPLATE_AFFINE=${ANTSCT_FILE_PREFIX}*SubjectToTemplate0GenericAffine.mat

# SST to OASIS warps from antsLongCT output
sstDir=${longRootDir}/${subj}/${subj}_SingleSubjectTemplate/

SST_TEMPLATE_WARP=${sstDir}T_templateSubjectToTemplate1Warp.nii.gz

SST_TEMPLATE_AFFINE=${sstDir}T_templateSubjectToTemplate0GenericAffine.mat

# MNI template and warp
MNI152_TEMPLATE=/data/grossman/pipedream2018/templates/OASIS/MNI152/MNI152_T1_1mm_brain.nii.gz

MNI152_TEMPLATE_WARP=/data/grossman/pipedream2018/templates/OASIS/MNI152/T_template0_ToMNI1521InverseWarp.nii.gz

MNI152_TEMPLATE_AFFINE="/data/grossman/pipedream2018/templates/OASIS/MNI152/T_template0_ToMNI1520GenericAffine.mat"


# while [[ $# -gt 0 ]]; do
for (( i = 0; i < ${#INPUT_DESCRIPTORS[@]}; i++ )); do
  cmd="${ANTSPATH}antsApplyTransforms -d 3 -i ${ANTSCT_FILE_PREFIX}*${INPUT_DESCRIPTORS[$i]}${SUFFIX} -r $MNI152_TEMPLATE -t $MNI152_TEMPLATE_WARP -t $MNI152_TEMPLATE_AFFINE -t $SST_TEMPLATE_WARP -t $SST_TEMPLATE_AFFINE -t $T1_TEMPLATE_WARP -t $T1_TEMPLATE_AFFINE -o ${outputDir}/${subj}_${tp}_${OUTPUT_DESCRIPTORS[$i]}${SUFFIX}"
  echo $cmd
  $cmd
done

done

