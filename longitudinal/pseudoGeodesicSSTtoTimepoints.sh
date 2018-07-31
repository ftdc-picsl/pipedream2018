#!/bin/sh

subj=$1

# tp=$2

longRootDir=$2

sstlabels=$3

outputSpace=normalizedToMNI152/
BinDir=/data/grossman/pipedream2018/longitudinal/scripts
antsPath=/data/grossman/pipedream2018/bin/ants/bin/
c3dpath=/share/apps/c3d/c3d-1.1.0-Nightly-2017-04-04/bin/

for tp_Dir in `ls -d --color=none ${longRootDir}/${subj}/${subj}_2*/` ; 
  do 
    tpa=$(echo $tp_Dir | rev | cut -d'/' -f2 | rev)
    tp=$(echo $tpa | cut -d '_' -f2)
    ANTSCT_FILE_PREFIX=${tp_Dir}/${subj}_${tp}

    SUFFIX=".nii.gz"

    # T1 to SST warps from antsLongCT output
    T1_TEMPLATE_WARP=${ANTSCT_FILE_PREFIX}*TemplateToSubject0Warp.nii.gz

    T1_TEMPLATE_AFFINE=${ANTSCT_FILE_PREFIX}*TemplateToSubject1GenericAffine.mat

    T1_NATIVE_IMAGE=${ANTSCT_FILE_PREFIX}*BrainSegmentation0N4.nii.gz

    cmd="${ANTSPATH}antsApplyTransforms -d 3 -i ${sstlabels} -r $T1_NATIVE_IMAGE -t $T1_TEMPLATE_AFFINE -t $T1_TEMPLATE_WARP -n MultiLabel -o ${ANTSCT_FILE_PREFIX}_SST_PG_antsLabelFusionLabelsToTimepoint${SUFFIX}"
    echo $cmd
    $cmd
done

