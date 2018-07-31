#!/bin/bash

BinDir=$1
subject=$2
tp=$3
outputDir=$4
inputDir=$5

echo "warpACT qscript BinDir = ${BinDir} "

ANTSCT_FILE_PREFIX=${inputDir}/${subject}_${tp}_

# Images to warp
INPUT_DESCRIPTORS=(CorticalThickness GMP)
OUTPUT_DESCRIPTORS=(CorticalThicknessNormalizedToMNI152  GMPNormalizedToMNI152)

SUFFIX=".nii.gz"


if [[ ! -f ${ANTSCT_FILE_PREFIX}GMP${SUFFIX} ]]; then
  ${BinDir}/createGMP.sh ${subject} ${tp}
fi 


if [[ ! -d ${outputDir} ]]; then
  mkdir -p ${outputDir}
fi


if [[ ${#INPUT_DESCRIPTORS[@]} -ne ${#OUTPUT_DESCRIPTORS[@]} ]]; then
  echo "Mapping of input files to output files does not match, exiting"
  exit 1
fi

for (( i = 0; i < ${#INPUT_DESCRIPTORS[@]}; i++ )); do
  echo "  ${INPUT_DESCRIPTORS[$i]} -> ${OUTPUT_DESCRIPTORS[$i]}"
done

for (( i = 0; i < ${#INPUT_DESCRIPTORS[@]}; i++ )); do
  ${BinDir}/warpT1ToMNI152.sh ${ANTSCT_FILE_PREFIX} ${ANTSCT_FILE_PREFIX}${INPUT_DESCRIPTORS[$i]}${SUFFIX} ${outputDir}/${subject}_${tp}_${OUTPUT_DESCRIPTORS[$i]}${SUFFIX} 
done
  
