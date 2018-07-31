#!/bin/bash

dataRootDir=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii/

templateDir=/data/grossman/pipedream2018/templates/OASIS/

procScriptDir=/data/grossman/pipedream2018/bin/scripts

binDir=/data/grossman/pipedream2018/bin

ANTSPATH=${binDir}/ants/bin/

if [[ $# -lt 4 ]]; then
cat <<USAGE

  $0 <subject> <timepoint> <outputRootDir>
  
  subject - subject ID
  timepoint - scan date

  Script looks for data in $dataRootDir

  Uses template in $templateDir

  Uses ANTs in $ANTSPATH

  outputRootDir - root directory for output; script creates subject/timepoint subdirectory 

  Example: $0 123456 20140301 /data/jet/me/output

USAGE

exit 1

fi

subj=$1

tp=$2

outputRootDir=$3

t1=`ls ${dataRootDir}/${subj}/${tp}/T1/*.nii.gz | tail -n 1` 

if [[ ! -f $t1 ]]; then
  echo
  echo " Cannot find T1 image in ${dataRootDir}/${subj}/${tp}/T1"
  echo
  exit 1
fi

outputTP_Dir=${outputRootDir}/${subj}/${tp}

if [[ -d "$outputTP_Dir" ]]; then
  echo
  echo " Output directory $outputTP_Dir already exists. Move it or set output root dir somewhere else "
  exit 1
fi

mkdir -p ${outputTP_Dir}

regOutputRoot="${outputTP_Dir}/${subj}_${tp}_reg_" 

initialBrainMask="${regOutputRoot}BrainMask.nii.gz"

template=${templateDir}/T_template0.nii.gz
templateBrainMask=${templateDir}/T_template0_BrainCerebellumMask.nii.gz
templateRegMask=${templateDir}/T_template0_BrainCerebellumRegistrationMask.nii.gz
segPriorsDir=${templateDir}/priors
segPriors=(`ls ${segPriorsDir}/priors*.nii.gz`)

cat ${ANTSPATH}version.txt > ${outputTP_Dir}/antsVersion.txt

scriptToRun=${outputTP_Dir}/antsctMNI_${subj}_${tp}.sh

cat > ${scriptToRun} << ANTSCT_MNI_SUBJ_JOB_SCRIPT

export ANTSPATH=${ANTSPATH}

ln -s $t1 ${outputTP_Dir}/${subj}_${tp}_t1Head.nii.gz

${procScriptDir}/crossSectional/brainExtractionRegistration.pl --input $t1 --template ${template} --template-brain-mask ${templateBrainMask} --template-reg-mask ${templateRegMask} --bias-correct 1 --laplacian-sigma 1 --seg-priors ${segPriors[@]} --float 1 --output-root ${regOutputRoot}

${procScriptDir}/crossSectional/brainExtractionSegmentation.pl --input $t1 --initial-brain-mask ${initialBrainMask} --bias-correct 1 --erosion-radius 0 --dilation-radius 2 --include-initial-classes 4 5 6 --output-root ${outputTP_Dir}/${subj}_${tp}_brainExtractationSegmentation_

cp ${regOutputRoot}BrainMask.nii.gz ${outputTP_Dir}/${subj}_${tp}_registrationBrainMask_tmp.nii.gz

cp ${outputTP_Dir}/${subj}_${tp}_brainExtractationSegmentation_BrainMask.nii.gz ${outputTP_Dir}/${subj}_${tp}_BrainExtractionMask.nii.gz

rm ${regOutputRoot}SegPrior{1..6}.nii.gz

rm ${regOutputRoot}BrainMask.nii.gz
rm ${regOutputRoot}TemplateToSubjectDeformed.nii.gz
rm ${outputTP_Dir}/${subj}_${tp}_brainExtractationSegmentation_BrainSegmentation.nii.gz
rm ${outputTP_Dir}/${subj}_${tp}_brainExtractationSegmentation_BrainMask.nii.gz

${procScriptDir}/crossSectional/qformCheck.sh ${subj} ${tp} $t1

${ANTSPATH}antsCorticalThickness.sh -d 3 -a $t1 -e ${template} -m ${templateDir}/T_template0_BrainCerebellumProbabilityMask.nii.gz -f ${templateRegMask} -p ${segPriorsDir}/priors%d.nii.gz -t ${templateDir}/T_template0_BrainCerebellum.nii.gz -o ${outputTP_Dir}/${subj}_${tp}_

rm ${outputTP_Dir}/${subj}_${tp}_SubjectToTemplateLogJacobian.nii.gz

${procScriptDir}/crossSectional/createGMP.sh ${subj} ${tp} ${outputRootDir} ${scriptDir} ${ANTSPATH}

${procScriptDir}/crossSectional/warpACT_OutputToMNI152_qscript.sh ${scriptDir} ${subj} ${tp} ${outputTP_Dir}/normalizedToMNI152 ${outputTP_Dir}

${procScriptDir}/crossSectional/indivHeatmap.sh ${subj}/${tp}

${binDir}/QuANTs/inst/bin/runQCTimepoint.pl --subject ${subj} --timepoint ${tp} --qsub 0

${procScriptDir}/crossSectional/pseudoGeodesicJointFusion_subj.sh ${subj} ${tp} ${outputTP_Dir}

${binDir}/QuANTs/inst/bin/runMindboggleTimepoint.pl --subject ${subj} --timepoint ${tp} --qsub 0

ANTSCT_MNI_SUBJ_JOB_SCRIPT

# Memory limits are a balance of speed (less RAM means more things run) and allocating enough RAM for every part of the pipeline
# 4-5 Gb seems to be the requirement of antsCorticalThickness right now
slots=2

cmd="qsub -l h_vmem=10G,s_vmem=9.8G -pe unihost $slots -binding linear:${slots} -S /bin/bash -cwd -o ${outputTP_Dir}/${subj}_${tp}.stdout -e ${outputTP_Dir}/${subj}_${tp}.stderr ${scriptToRun}"


echo $cmd
echo
$cmd
sleep 0.5
echo

