#!/bin/bash


if [[ $# -lt 2 ]]; then
  echo \
"
  $0 <subjlist> <longBaseDir>

  Wrapper for labeling SSTs with OASIS labels using pseudo geodesic registration (via group template) of atlases  
  Looks for SST in subj directory from subjList in longBaseDir
  Outputs into SST directory

  subjList can be either a list of just IDs or a CSV where ID is the first field
" 

exit 1

fi
subjList=$1
longBaseDir=$2

for i in `cat $subjList`; do 
  id=$(echo $i | cut -d ',' -f1)
  inimg=${longBaseDir}/${id}/${id}_SingleSubjectTemplate/T_templatePG_antsLabelFusionLabels.nii.gz
  outimg=${longBaseDir}/${id}/${id}_SingleSubjectTemplate/T_templatePG_antsLabelFusionLobar.nii.gz
  if [[ -f ${inimg} ]] ; then
    cmd="qsub -l h_vmem=2G,s_vmem=1.8G -pe unihost 1 -S /bin/bash -j y -o ${longBaseDir}/${id}/logs/${id}_oasisLabelsToLobar.stdout /data/grossman/pipedream2018/templates/OASIS/labels/OASIS30/oasisLabelsToLobar.sh ${inimg} ${outimg}"
    echo $cmd
    $cmd
    echo 
    sleep .5
  else 
    echo "No ${longBaseDir}/${id}/${id}_SingleSubjectTemplate/T_templatePG_antsLabelFusionLabels.nii.gz file" 
  fi

done

