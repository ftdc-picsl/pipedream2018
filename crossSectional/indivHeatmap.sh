#!/bin/bash -e

####---------Calculates Z-Score and Output Heatmap Render--------#######
####----Date Updated: 8/29/17 Authors: Katherine Xu & Charles Jester; Updated 6/4/18 with new filepath for pipedream2018 and manual thresholding to 1.75-5.
####----This script calculates the z-score of a test image against a control set. The z-score image is then rendered into an image using the vol2surf.sh and onscenetest2.sh script

if [[ $# -lt 1 ]]; then
cat <<USAGE

	$0 <subject> 
  
      	subject -  INDDID and Timepoint, separated by "/"


USAGE

exit 1

fi

#######------------Sets paths and names-----------##########
#######-------------------------------------------##########
idtp=$1
antsRT=/data/grossman/pipedream2018/crossSectional/antsct/
scriptRT=/data/grossman/tools/workbench/scripts/
indRT=$antsRT/$idtp/normalizedToMNI152/
ctxRaw=$indRT/${idtp/\//_}_CorticalThicknessNormalizedToMNI152.nii.gz
ctxPre=$indRT/${idtp/\//_}_s1_ctxNormToMNI
ctxSmooth=${ctxPre}.nii.gz
avg=/data/grossman/tools/workbench/scripts/s1_156controls_average_pipedream2018.nii.gz
stdev=/data/grossman/tools/workbench/scripts/s1_156controls_stdev_pipedream2018.nii.gz
clustersize=250
fsldir=/share/apps/fsl/5.0.9/bin/

##############################################################################################################################

# Smooths the Cortical Thickness before generating all of the output needed to make zscores
SmoothImage 3 ${ctxRaw} 1 $ctxSmooth 0 0

# The average is subtracted from the test file and divided by the standard deviation
fslmaths ${ctxSmooth} -sub $avg -div $stdev ${ctxPre}_tmp1.nii.gz

# Z-scores below -5 are replaced with -5. This is a manual form of thresholding.
ImageMath 3 ${ctxPre}_tmp2.nii.gz ReplaceVoxelValue ${ctxPre}_tmp1.nii.gz -inf -5 -5

# Z-scores above -1.5 are replaced with 0. This is a manual form of thresholding.
ImageMath 3 ${ctxPre}_tmp3.nii.gz ReplaceVoxelValue ${ctxPre}_tmp2.nii.gz -1.75 inf 0

# For puposes of visualization, all the negative z-scores are inverted and made positive by multiplying by -1
ImageMath 3 ${ctxPre}_invZ.nii.gz m ${ctxPre}_tmp3.nii.gz -1

rm ${ctxPre}_tmp*.nii.gz

if [[ $clustersize != 0 ]];then

	c3d ${ctxPre}_invZ.nii.gz -comp -o ${ctxPre}_comp.nii.gz

	#Change minextent for changing cluster sizes!
	last=`${fsldir}/cluster -i ${ctxPre}_comp.nii.gz -t 1 --minextent=$clustersize --mm | tail -1 | awk '{print $1}'`
	first=`${fsldir}/cluster -i ${ctxPre}_comp.nii.gz -t 1 --minextent=$clustersize --mm | head -2 | tail -1 | awk '{print $1}'`

	echo
	echo $first
	echo

	fslmaths ${ctxPre}_comp.nii.gz -thr $last -uthr $first -bin -mul ${ctxPre}_invZ.nii.gz ${ctxPre}_indivHeatmap.nii.gz

	#Running scripts to generate the L/R surf.nii and generate render
	$scriptRT/antsct_heatmap.sh -f ${ctxPre}_indivHeatmap.nii.gz --z_score_scale

rm ${ctxPre}_indivHeatmap_L.shape.gii
rm ${ctxPre}_indivHeatmap_R.shape.gii
rm ${ctxPre}_indivHeatmap_scene.scene
rm ${ctxPre}.nii.gz
rm ${ctxPre}_invZ.nii.gz
rm ${ctxPre}_comp.nii.gz

else
	$scriptRT/antsct_heatmap.sh -f  ${ctxPre}_indivHeatmap.nii.gz --z_score_scale

rm ${ctxPre}_indivHeatmap_L.shape.gii
rm ${ctxPre}_indivHeatmap_R.shape.gii
rm ${ctxPre}_indivHeatmap_scene.scene
rm ${ctxPre}.nii.gz
rm ${ctxPre}_invZ.nii.gz
rm ${ctxPre}_comp.nii.gz

fi
