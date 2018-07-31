#!/bin/sh

if [[ $# -lt 3 ]]; then
echo \
"
   $0 <subject> <timepoint> <antsct directory>
   outputs lstats 

"
exit 1
fi

su=$1
tp=$2
ctbase=$3

#roots
labelrt=/data/grossman/master_templates/labels/
antspath=/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/bin/ants
c3ddir=/share/apps/c3d/c3d-1.0.0-Linux-x86_64/bin/
outrt=${ctbase}/${su}/${tp}/labels/stats/${su}_${tp}_
sublabels=${ctbase}/${su}/${tp}/labels/${su}_${tp}_subject
warpdir=/data/grossman/master_templates/warps/mni_to_oasis/
posset=`printf mindboggle"\n"pd25"\n"midevel"\n"path"\n"jhuwm`
ctrt=`dirname $ctbase`
wmrt=${ctrt}/DTI/output/${su}/${tp}/DTI_Norm/

#Atlas sets
pathat=/data/grossman/master_templates/labels/PathAtlas/PathAtlas_MNI.nii.gz
pd25at=/data/grossman/master_templates/labels/PD25/pd25_labels_MNI.nii.gz
midat=/data/grossman/master_templates/labels/MidEveL/MidEveL_MNI152.nii.gz
mindat=/data/grossman/master_templates/labels/mind-boggle/mind-boggle_DeepGM_CortGM_oasis.nii.gz
jhuwmat=/data/grossman/master_templates/labels/JHU/JHU_WM_labels_MNI152.nii.gz

#Specify images to get info from
gmp=${ctbase}/${su}/${tp}/${su}_${tp}_GMP.nii.gz
ct=${ctbase}/${su}/${tp}/${su}_${tp}_CorticalThickness.nii.gz
fa=${wmrt}/${su}_${tp}_faNormMNI152.nii.gz
t2saffine=${ctbase}/${su}/${tp}/${su}_${tp}_TemplateToSubject1GenericAffine.mat
t2swarp=${ctbase}/${su}/${tp}/${su}_${tp}_TemplateToSubject0Warp.nii.gz
m2oaffine=${warpdir}/MNItoOASISwarp0GenericAffine.mat
m2owarp=${warpdir}/MNItoOASISwarp1Warp.nii.gz
brainex=${ctbase}/${su}/${tp}/${su}_${tp}_ExtractedBrain0N4.nii.gz
exbrain=${ctbase}/${su}/${tp}/${su}_${tp}_BrainExtractionMask.nii.gz

# makes the JLF dir if non-existing
if [[ ! -d ${ctbase}/${su}/${tp}/labels/stats ]]; then

    mkdir -p ${ctbase}/${su}/${tp}/labels/stats

fi

#Begin checking each possible label set
for imageset in `echo $posset`; do
 
#output files
ctlstat=${outrt}CorticalThicknessLstats_${imageset}.txt
gmplstat=${outrt}GMPLstats_${imageset}.txt
gmpout=${outrt}gmp_${imageset}.csv
ctxout=${outrt}ctx_${imageset}.csv
volout=${outrt}vol_${imageset}.csv

maskedgmLabels=${ctbase}/${su}/${tp}/labels/${su}_${tp}_masked_subject_${imageset}.nii.gz

#Checks that label image is generated or not
if [[ ! -f ${sublabels}_${imageset}.nii.gz ]]; then 

if [[ $imageset == "mindboggle" ]]; then
    
    cmd="$antspath/antsApplyTransforms -d 3 -i $mindat -r $gmp -t $t2saffine -t $t2swarp -n MultiLabel -o ${sublabels}_${imageset}.nii.gz"
    echo $cmd
    echo
    $cmd

elif [[ $imageset == "midevel" ]]; then
    
   cmd="$antspath/antsApplyTransforms -d 3 -i $midat -r $gmp -t $t2saffine -t $t2swarp -t $m2oaffine -t $m2owarp -n MultiLabel -o ${sublabels}_${imageset}.nii.gz"
    echo $cmd
    echo
    $cmd

elif [[ $imageset == "pd25" ]]; then

   cmd="$antspath/antsApplyTransforms -d 3 -i $pd25at -r $gmp -t $t2saffine -t $t2swarp -t $m2oaffine -t $m2owarp -n MultiLabel -o ${sublabels}_${imageset}.nii.gz"
    echo $cmd
    echo
    $cmd

elif [[ $imageset == "jhuwm" ]]; then

   cmd="$antspath/antsApplyTransforms -d 3 -i $jhuwmat -r $gmp -t $t2saffine -t $t2swarp -t $m2oaffine -t $m2owarp -n MultiLabel -o ${sublabels}_${imageset}.nii.gz"
    echo $cmd
    echo
    $cmd

#Will create the the path image from native label sets
elif [[ $imageset == "path" ]]; then

    pathroot=/data/grossman/master_templates/labels/PathAtlas/
    mind_rep=`cat $pathroot/PathOASIS.txt | tr '\n' ' '`
    midevel_rep=`cat $pathroot/PathMidEveL.txt | tr '\n' ' '`
    pd25_rep=`cat $pathroot/PathPD25.txt | tr '\n' ' '`
    jhuwm_rep=`cat $pathroot/PathJHUWM.txt | tr '\n' ' '`

    tmp_pathmind=${TMPDIR}/${su}_${tp}_pathmind.nii.gz
    tmp_pathmidevel=${TMPDIR}/${su}_${tp}_pathmidevel.nii.gz
    tmp_pathpd25=${TMPDIR}/${su}_${tp}_pathpd25.nii.gz
    tmp_pathjhuwm=${TMPDIR}/${su}_${tp}_pathjhuwm.nii.gz

    cmd_mind="c3d ${sublabels}_mindboggle.nii.gz -replace $mind_rep -o $tmp_pathmind"
    echo $cmd_mind
    $cmd_mind
    echo
    
    cmd_midevel="c3d ${sublabels}_midevel.nii.gz -replace $midevel_rep -o $tmp_pathmidevel"
    echo $cmd_midevel
    $cmd_midevel
    echo

    cmd_pd25="c3d ${sublabels}_pd25.nii.gz -replace $pd25_rep -o $tmp_pathpd25"
    echo $cmd_pd25
    $cmd_pd25
    echo
    
    cmd_jhuwm="c3d ${sublabels}_jhuwm.nii.gz -replace $jhuwm_rep -o $tmp_jhuwm"
    echo $cmd_jhuwm
    $cmd_jhuwm
    echo

    cmd_path="c3d $tmp_pathmidevel $tmp_pathmind $tmp_pathpd25 $tmp_pathjhuwm -accum -add -endaccum -replace 187 0 188 0 189 0 193 0 194 0 195 0 -o ${sublabels}_${imageset}.nii.gz"
    echo $cmd_path
    $cmd_path
    echo

fi
fi

## mask labels by separate (atropos) GM segmentation: pseudoGeo labels generally too fat
# inlabels
seg=${ctbase}/${su}/${tp}/${su}_${tp}_BrainSegmentation.nii.gz 
# outlabels
gmLabels=${sublabels}_${imageset}.nii.gz

${c3ddir}/c3d ${seg} -replace 1 0 3 0 6 0 -thresh 1 Inf 1 0 ${gmLabels} -multiply -o ${maskedgmLabels}

if [[ $imageset == "mindboggle" ]] || [[ $imageset == "path" ]]; then

# get lstats 
    ${c3ddir}/c3d ${gmp} ${maskedgmLabels} -lstat > ${gmplstat}
    ${c3ddir}/c3d ${ct} ${maskedgmLabels} -lstat > ${ctlstat}

#output a formatted csv, with anatomical labels

    if [[ $imageset == "mindboggle" ]]; then 

	names=${labelrt}mind-boggle/mind-boggle_ref.csv

    elif [[ $imageset == "path" ]]; then

	names=${labelrt}PathAtlas/PathAtlas_ref.csv

    fi

    tmpgm=${outrt}tmp_gm_${imageset}.txt
    tmpct=${outrt}tmp_ct_${imageset}.txt


    printf "INDDID,Timepoint," > ${tmpgm}
    printf "INDDID,Timepoint," > ${tmpct}

#a quick for loop to generate the label headers for each file
    for gmps in `awk '{print $1}' $gmplstat | egrep "^[1-9]"`; do

	cat ${names} | egrep -w "^$gmps" | cut -d ',' -f 2 >> ${tmpgm}

    done

    for ctxs in `awk '{print $1}' $ctlstat | egrep "^[0-9]{3}|31|32|47|48"`; do

	cat ${names} | egrep -w "^$ctxs" | cut -d ',' -f 2 >> ${tmpct}
    
    done
 
    cat $tmpgm | tr '\n' ',' | sed 's/,$//g' > $gmpout
    cat $tmpct | tr '\n' ',' | sed 's/,$//g' > $ctxout
    namevol=`cat $tmpgm | tr '\n' ',' | sed 's/,$//g'` 
    printf $namevol","ICV > $volout

    rm $tmpgm $tmpct

    printf "\n"${su}","${tp} >> $gmpout
    printf "\n"${su}","${tp}  >> $volout

    for gmplab in `awk '{print $1}' $names | egrep "^[1-9]" | cut -d ',' -f1`; do

# grabs all means for each label collected using gmp and ct
	gmplabels=`awk '{print $1,$2}' ${gmplstat} | egrep -w "^$gmplab" | awk '{print $2}'`
	vollabels=`awk '{print $1,$7}' ${gmplstat} | egrep -w "^$gmplab" | awk '{print $2}'`

	printf ","$gmplabels >> $gmpout
	printf ","$vollabels >> $volout
    done

    icv=`c3d $exbrain $brainex -lstat | awk 'FNR == 3 {print $7}'`

    printf ","$icv >> $volout

    printf "\n"${su}","${tp} >> $ctxout

    if [[ $imageset == "path" ]]; then 

	for ctlab in `awk '{print $1}' $names | egrep "^1[0-9]{2}|31|32|47|48" | cut -d ',' -f 1`; do

	    ctlabels=`awk '{print $1,$2}' ${ctlstat} | egrep -w "^$ctlab" | awk '{print $2}'`

	    printf ","$ctlabels >> $ctxout

	done

    else

	for ctlab in `awk '{print $1}' $names | egrep "^[0-9]{3}|31|32|47|48" | cut -d ',' -f 1`; do

	    ctlabels=`awk '{print $1,$2}' ${ctlstat} | egrep -w "^$ctlab" | awk '{print $2}'`

	    printf ","$ctlabels >> $ctxout

	done

    fi

fi

if [[ $imageset == "midevel" ]] || [[ $imageset == "pd25" ]]; then

    ${c3ddir}/c3d ${gmp} ${maskedgmLabels} -lstat > ${gmplstat}

    if [[ $imageset == "midevel" ]]; then

	names=${labelrt}MidEveL/MidEveL_ref.csv

    elif [[ $imageset == "pd25" ]]; then

	names=${labelrt}PD25/PD25_ref.csv

    fi

    tmpgm=${outrt}tmp_gm_${imageset}.txt

    printf "INDDID,Timepoint," > ${tmpgm}

#a quick for loop to generate the label headers for each file
    for gmps in `awk '{print $1}' $gmplstat | egrep "^[1-9]"`; do

	cat ${names} | egrep -w "^$gmps" | cut -d ',' -f 2 >> ${tmpgm}

    done

    cat $tmpgm | tr '\n' ',' | sed 's/,$//g' > $gmpout
    namevol=`cat $tmpgm | tr '\n' ',' | sed 's/,$//g'` 
    printf $namevol","ICV > $volout

    rm $tmpgm 

    printf "\n"${su}","${tp} >> $gmpout
    printf "\n"${su}","${tp}  >> $volout

    for gmplab in `awk '{print $1}' $names | egrep "^[1-9]" | cut -d ',' -f1`; do

# grabs all means for each label collected using gmp and ct
	gmplabels=`awk '{print $1,$2}' ${gmplstat} | egrep -w "^$gmplab" | awk '{print $2}'`
	vollabels=`awk '{print $1,$7}' ${gmplstat} | egrep -w "^$gmplab" | awk '{print $2}'`

	echo $gmplab
	printf ","$gmplabels >> $gmpout
	printf ","$vollabels >> $volout
    done

    icv=`c3d $exbrain $brainex -lstat | awk 'FNR == 3 {print $7}'`

    printf ","$icv >> $volout



fi

done