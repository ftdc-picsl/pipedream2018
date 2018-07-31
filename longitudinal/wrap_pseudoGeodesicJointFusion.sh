#!/bin/bash


if [[ $# -lt 2 ]]; then
  echo \
"
  $0 <subjlist> <longBaseDir>

  Wrapper for labeling SSTs with OASIS labels using pseudo geodesic registration (via group template) of atlases  
  Looks for SST in subj directory from subjList in longBaseDir
  Outputs into SST directory

  subjList can be either a list of just IDs, a CSV where ID is the first field, or a single subject ID
" 

exit 1

fi
slots=2
subjList=$1
longBaseDir=$2

scriptDir=`dirname $0`

if [[ -f $subjList ]]; then
    subjects=`cat $subjList`
else
    subjects=$subjList
fi

for i in $subjectList; do 
  id=$(echo $i | cut -d ',' -f 1)

  outputDir=${longBaseDir}/${subj}/${subj}_SingleSubjectTemplate/

  if [[ ! -f ${outputDir}/T_templatePG_antsLabelFusionLobar.nii.gz ]] ; then

      sstRoot="${outputDir}/T_template"

      sstBrain="${sstRoot}BrainExtractionBrain.nii.gz"
      
      sstBrainMask="${sstRoot}BrainExtractionMask.nii.gz"
      
      templateToT1Warp="${sstRoot}TemplateToSubject0Warp.nii.gz"

      templateToT1Affine="${sstRoot}TemplateToSubject1GenericAffine.mat"

      scriptToRun=${outputDir}/pgJLF_${id}.sh

      cat > ${scriptToRun} << JLF_SUBJ_JOB_SCRIPT

${scriptDir}/pseudoGeodesicJointFusion.pl $sstBrain $sstBrainMask $templateToT1Warp $templateToT1Affine ${outputDir} T_template
      
${scriptDir}/pseudoGeodesicSSTtoTimepoints.sh ${subj} ${longDir} ${outputDir}/T_templatePG_antsLabelFusionLabels.nii.gz

JLF_SUBJ_JOB_SCRIPT

    cmd="qsub -l h_vmem=9G,s_vmem=8.8G -pe unihost $slots -binding linear:${slots}  -S /bin/bash -o ${longBaseDir}/${id}/logs/${id}_pseudoGeodesicJointFusion.stdout -e ${longBaseDir}/${id}/logs/${id}_pseudoGeodesicJointFusion.stderr $scriptToRun"
    echo $cmd
    $cmd
    echo 
    sleep 0.5
  fi
done
