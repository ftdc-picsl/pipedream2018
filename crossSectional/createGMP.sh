#!/bin/bash


# Creates a combined gray matter probability image-- includes BrainSegmentationPosterior 02=cortex, 04=deep gray, and 05=brainstem  images


if [[ $# -lt 5 ]]; then
  echo " 

    $0 <subject> <timepoint> <in/out base> <scriptsDir> <ANTSPATH>
  "

  exit 1

fi 

SUBJECT=$1

TP=$2

OUTBASE=$3

BINDIR=$4

ANTSPATH=$5

shift 2


if [[ ! -d $TMPDIR ]] ; then

    echo
    echo " No TMPDIR: exiting..."
    echo
    exit 1
fi


ANTSCT_FILE_PREFIX=${OUTBASE}/${SUBJECT}/${TP}/${SUBJECT}_${TP}_

if [ -f ${ANTSCT_FILE_PREFIX}CorticalThickness.nii.gz ] ; then

    if [ ! -f ${ANTSCT_FILE_PREFIX}GMP.nii.gz ] ; then 

	${ANTSPATH}ImageMath 3 ${TMPDIR}BrainSegmentationPosteriors24.nii.gz + ${ANTSCT_FILE_PREFIX}BrainSegmentationPosteriors2.nii.gz ${ANTSCT_FILE_PREFIX}BrainSegmentationPosteriors4.nii.gz

	${ANTSPATH}ImageMath 3 ${ANTSCT_FILE_PREFIX}GMP.nii.gz + ${TMPDIR}BrainSegmentationPosteriors24.nii.gz ${ANTSCT_FILE_PREFIX}BrainSegmentationPosteriors5.nii.gz

	${BINDIR}/warpT1ToMNI152.sh ${SUBJECT} ${TP} ${ANTSCT_FILE_PREFIX}GMP.nii.gz ${OUTBASE}/${SUBJECT}/${TP}/normalizedToMNI152/${SUBJECT}_${TP}_GMPNormMNI152.nii.gz

    else
	echo 
	echo "${ANTSCT_FILE_PREFIX}GMP.nii.gz exists"
	echo 
	exit 1
    fi

else
    echo 
    echo "Cortical thickness hasn't run ${SUBJECT} ${TP}"
    echo
    exit 1
fi

