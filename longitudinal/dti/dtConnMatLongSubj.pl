#!/usr/bin/perl -w
#
# Wrapper script for calling dtConnMat.pl for some or all of a subject's data
#

use strict;
use FindBin qw($Bin);
use File::Path;
use File::Spec;
use File::Basename;
use Getopt::Long;

# CSV file containing label definitions
my $labelDefs = "${Bin}/mindBoggleCortSubCortGraphNodes.csv";

my $antsPath = "/data/grossman/pipedream2018/bin/ants/bin/";

# Path where ANTsR etc can be found
my $rLibsUserPath = "/data/grossman/pipedream2018/bin/R/R-3.4.3/library";

my $caminoDir = "/data/grossman/pipedream2018/bin/camino/bin";


# Two cores because we have Java and R running at the same time to reduce disk I/O
my $cores=2;

my $ram="8";
my $submitToQueue=1;

my $usage = qq{

  $0  
      --subject
      --antslongct-base-dir
      --longdt-base-dir
      [ options ]

  Required args:

   --subject
     Subject ID

   --antslongct-base-dir 
     Base antsLongCT dir for T1 data, including labeling of the SST.
  
   --longdt-base-dir
     Base longitudinal DTI dir. There should be DT data for the time point(s) to be processed, and 
     an average FA image under subject/singleSubjectTemplate/subject_averageFA.nii.gz.

 
  Wrapper script for building matrices of cortical connectivity. Calls dtConnMat.pl, see that script for additional options. 

  Some input for the processing is generated at run time so it is best to run this script from a qlogin session.


  Options:

   --timepoints  
     Timepoint(s) to process. If no time points are provided, it means process all available timepoints.

   --qsub
     Submit processing jobs to qsub (default = $submitToQueue).

   --ram
     Amount of RAM to request, in G (default = $ram).

   --cores 
     Number of CPU cores to request (default = $cores).



  T1, brain mask, and segmentation probabilities come from antsLongCT.

  The SST should be labeled using the pseudo-geodesic JLF.

  DT data is read from

    \${longdt-base-dir}/subj/tp/

  The long DTI preprocessing pipeline should have been run, such that dt/ and distCorr/ exist; 
  these will be used to do the tracking and transfer the results to SST space.

  
  Output:

    See dtConnMat.pl for details of output.

};

if ($#ARGV < 0) {
    print $usage;
    exit 1;
}


# Input base dir for DT data
my $inputBaseDir = "";

# For T1 brain and other useful stuff
my $antsLongCT_BaseDir = "";


my $subject = "";
my @timepoints = ();

GetOptions ("subject=s" => \$subject,
	    "timepoints=s{1,1000}" => \@timepoints,
	    "antslongct-base-dir=s" => \$antsLongCT_BaseDir,
	    "longdt-base-dir=s" => \$inputBaseDir,
	    "qsub=i" => \$submitToQueue,
	    "ram=s" => \$ram,
	    "cores=i" => \$cores
    )
    or die("Error in command line arguments\n");


my $sysTmpDir = $ENV{'TMPDIR'};

# Directory for temporary files that is deleted later if $cleanup
my $tmpDir = "";

my $tmpDirBaseName = "${subject}_dtConnMat";

if ( !($sysTmpDir && -d $sysTmpDir) ) {
    $tmpDir = "/tmp" . "/${tmpDirBaseName}";
}
else {
    # Have system tmp dir
    $tmpDir = $sysTmpDir . "/${tmpDirBaseName}";
}

# Gets removed later, so check we can create this and if not, exit immediately
mkpath($tmpDir, {verbose => 0, mode => 0755}) or die "Cannot create working directory $tmpDir (maybe it exists from a previous failed run)\n\t";


# output to $inputBaseDir/subj/tp/connMat
my $outputBaseDir = $inputBaseDir;

my $qVmem = "${ram}G";

# set Camino memory limit
my $caminoHeapSize = 3200;

my $numTimepoints = scalar(@timepoints);

if ($numTimepoints == 0) {
    @timepoints = `ls ${inputBaseDir}/${subject} | grep -v singleSubjectTemplate`;

    chomp @timepoints;

    $numTimepoints = scalar(@timepoints);

    if ($numTimepoints == 0) {
	print "\n  No DT data to process for $subject\n";
	exit 1;
    }
}

my $parallel="";

if ($cores > 1) {
    $parallel="-pe unihost $cores -binding linear:$cores"; 
}


# Submit each time point

# Output is in SST space
my $sstOutputRoot = "${antsLongCT_BaseDir}/${subject}/${subject}_SingleSubjectTemplate/T_template";

my $sst = "${sstOutputRoot}ExtractedBrain0N4.nii.gz";

my $jlfLabels = "${sstOutputRoot}PG_antsLabelFusionLabels.nii.gz";

# Use SST segmentation or could use JLF converted to six classes 
my $sstSixClassSeg = "${sstOutputRoot}BrainSegmentation.nii.gz";


for ( my $i=0; $i < $numTimepoints; $i++ ) {
    my $tp = $timepoints[$i];
    
    my $tpDTI_Dir = "${inputBaseDir}/${subject}/${tp}";

    my $tpAntsCT_Dir = `ls -d ${antsLongCT_BaseDir}/${subject}/* | grep "_${tp}_"`;

    chomp $tpAntsCT_Dir;

    if (! -d "$tpAntsCT_Dir") {
	print "\n  Incomplete or missing ANTsCT data for $subject $tp \n";
	next;
    }

    my $segmentation = `ls ${tpAntsCT_Dir} | grep "BrainSegmentation.nii.gz"`;

    chomp $segmentation;

    # Check for correct input
    if (! -f "${tpAntsCT_Dir}/$segmentation") {
	print "\n  Incomplete or missing ANTsCT data for $subject $tp \n";
	next;
    }

    $segmentation =~ m/(${subject}_${tp}_.*)BrainSegmentation.nii.gz/;

    my $tpAntsCT_FileRoot = $1;
    
    my $tpAntsCT_OutputRoot = "${tpAntsCT_Dir}/${tpAntsCT_FileRoot}";


    my $dt = "${tpDTI_Dir}/dt/${subject}_${tp}_DT.nii.gz";
    
    my $dtMask = "${tpDTI_Dir}/dt/${subject}_${tp}_BrainMask.nii.gz";

    my $outputTP_Dir = "${outputBaseDir}/${subject}/${tp}/connMatSST";     

    if (-d $outputTP_Dir) {
	print "\n  Output already exists for $subject $tp \n";
	next;
    }

    # Check for correct input
    if (! -f "${tpAntsCT_OutputRoot}CorticalThickness.nii.gz") {
	print "\n  Incomplete or missing ANTsCT data for $subject $tp \n";
	next;
    }
    if (! -f "${sstSixClassSeg}") {
	print "\n  Missing six class labels for $subject $tp \n";
	next;
    }

    if (! -f "$dt" ) {
	print "\n  No DT for $subject $tp\n";
	next;
    }

    my $averageFA = "${inputBaseDir}/${subject}/singleSubjectTemplate/${subject}_AverageFA.nii.gz";
    
    if (! -f $averageFA) {
	    die("Cannot submit subject, missing SST average FA");
    }
    
    # SST average FA used to constrain exclusion. Only exclude if CSF && FA < threshold (see sub)
    my $exclusionMask = "${inputBaseDir}/${subject}/singleSubjectTemplate/${subject}_ExclusionMask.nii.gz";
    
    if (! -f $exclusionMask ) {
	
	# Make consistent exclusion mask per subject. Limit tracts to voxels inside SST brain mask
	# and additionally exclude those labeled CSF && average FA < threshold (see sub)

	my $sstMask = "${sstOutputRoot}BrainExtractionMask.nii.gz";
	
	# This will be used to truncate tracts traversing CSF
	my $sstCSFPosterior = "${sstOutputRoot}BrainSegmentationPosteriors1.nii.gz";
	
	createSubjectExclusionMask($sstMask, $averageFA, $sstCSFPosterior, $exclusionMask);
    }

    
    # SST average FA used to constrain cortical nodes. Only count node if labeled && FA < threshold (see sub)
    my $graphNodes = "${inputBaseDir}/${subject}/singleSubjectTemplate/${subject}_GraphNodes.nii.gz";
    
    if (! -f $graphNodes) {
	createSubjectGraphNodes($averageFA, $jlfLabels, $labelDefs, $graphNodes);
    }
    
    mkpath($outputTP_Dir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputTP_Dir\n\t";

    # compose a warp to the SST, note this is for point sets so we need inverses

    my $t1ToSSTWarp = "${tpAntsCT_OutputRoot}TemplateToSubject0Warp.nii.gz";
    my $t1ToSSTAffine = "${tpAntsCT_OutputRoot}TemplateToSubject1GenericAffine.mat";

    my $distCorrInvWarp = "${tpDTI_Dir}/distCorr/${subject}_${tp}_DistCorr1InverseWarp.nii.gz";
    my $distCorrAffine = "${tpDTI_Dir}/distCorr/${subject}_${tp}_DistCorr0GenericAffine.mat";

    my $composedWarp = "${outputTP_Dir}/${subject}_${tp}_tractWarpToSST.nii.gz";

    system("${antsPath}antsApplyTransforms -d 3 -i $sst -r $dtMask -t [${distCorrAffine}, 1] -t $distCorrInvWarp -t $t1ToSSTAffine -t $t1ToSSTWarp -o [${composedWarp}, 1] --verbose");
    
    my $logFile = "${outputTP_Dir}/connMat_${subject}_${tp}_log.txt";
    
    my $scriptToRun = "${outputTP_Dir}/connMat_${subject}_${tp}.sh";

    my $antsVersion = `cat ${antsPath}version.txt`;
    chomp $antsVersion;

    my $fh;

    open($fh, ">", $logFile);

    print $fh "ANTs version: ${antsVersion}\n\n";
    
    close($fh);

    open($fh, ">", $scriptToRun);
    
    # Set paths here so they can't get altered by user profiles
    
    print $fh qq{
export ANTSPATH=${antsPath}

export PATH=${caminoDir}:${antsPath}:\${PATH}

export CAMINO_HEAP_SIZE=${caminoHeapSize}

export R_LIBS=""

export R_LIBS_USER=${rLibsUserPath}

${Bin}/dtConnMat.pl \\
    --dt $dt \\
    --mask $dtMask \\
    --reference-image $sst \\
    --composed-warp $composedWarp \\
    --exclusion-image $exclusionMask \\
    --label-image $graphNodes \\
    --label-def $labelDefs \\
    --output-root ${outputTP_Dir}/${subject}_${tp}_ \\
    --seed-spacing 1 \\
    --seed-fa-thresh 0.2 \\
    --curve-thresh 80 \\
    --compute-scalars 1 

};

    close $fh;
    
    if ($submitToQueue) {
	system("qsub -l h_vmem=${qVmem},s_vmem=${qVmem} $parallel -cwd -S /bin/bash -j y -o $logFile $scriptToRun");
	system("sleep 0.25");
    }
    else {
	system("$scriptToRun >> $logFile 2>&1");
    }
    
    
} # for all timepoints


system("rm $tmpDir/*");
system("rmdir $tmpDir");

#
# Makes an exclusion mask in the SST space
#
# createSubjectExclusionMask($brainMask, $averageFA, $csf, $maskFile)
#
sub createSubjectExclusionMask  {

    my ($brainMask, $averageFA, $csfPosterior, $exclusionMask) = @_;

    my $tmpMask = "/tmp/${subject}_exclusionMask.nii.gz";

    my $csfExclusionMask = "${tmpDir}/csfExclusionMask.nii.gz";

    system("${antsPath}ThresholdImage 3 $csfPosterior $csfExclusionMask 0.5 1.1");

    my $sstFAThresh = "${tmpDir}/faExclusionMask.nii.gz";

    system("${antsPath}ThresholdImage 3 ${averageFA} $sstFAThresh 0 0.09999");

    system("${antsPath}ImageMath 3 $tmpMask m $csfExclusionMask $sstFAThresh");

    # Also exclude anything outside the SST brain mask
    my $sstBrainMaskInv = "${tmpDir}/sstBrainMaskInv.nii.gz";

    system("${antsPath}ThresholdImage 3 $brainMask $sstBrainMaskInv 0 0.5");

    system("${antsPath}ImageMath 3 $tmpMask + $tmpMask $sstBrainMaskInv");

    system("${antsPath}ThresholdImage 3 $tmpMask $tmpMask 1 Inf");
    
    # Keep only final exclusion mask
    system("cp $tmpMask $exclusionMask");
    
    system("rm $tmpMask $csfExclusionMask $sstFAThresh $sstBrainMaskInv");

}


#
# Makes the graph nodes in the SST space
#
# Nodes are masked with average FA < 0.2, to stop mislabeled WM being called a node.
#
# Small clusters of high FA are ignored, to prevent noise from masking errors affecting
# the nodes.
#
# createSubjectGraphNodes($subject, $averageFA, $jlfLabels, $labelDef, $nodeFile)
#
sub createSubjectGraphNodes {

    my ($averageFA, $jlfLabels, $labelDef, $nodeFile) = @_;

    system("${caminoDir}/conmat -outputroot ${tmpDir}/conmat_ -targetfile $jlfLabels -targetnamefile $labelDef -outputnodes");

    my $corticalNodeMask = "${tmpDir}/corticalNodeMask.nii.gz";
    
    system("${antsPath}ThresholdImage 3 ${tmpDir}/conmat_nodes.nii.gz $corticalNodeMask 100 Inf");
 
    my $sstFAThresh = "${tmpDir}/${subject}_faExclusionMask.nii.gz";

    system("${antsPath}ThresholdImage 3 $averageFA $sstFAThresh 0.2 Inf");

    # Get rid of junk FA around the edge of the brain
    system("${antsPath}LabelClustersUniquely 3 $sstFAThresh $sstFAThresh 10000");

    system("${antsPath}ThresholdImage 3 $sstFAThresh $sstFAThresh 1 Inf");

    system("${antsPath}ImageMath 3 $corticalNodeMask m $sstFAThresh $corticalNodeMask");

    # $corticalNodeMask now intersection of (FA > 0.2, small clusters removed) & cortical GM labels
    # Remove these voxels from node image
    system("${antsPath}ThresholdImage 3 $corticalNodeMask $corticalNodeMask 1 1 0 1");

    system("${antsPath}ImageMath 3 $nodeFile m ${tmpDir}/conmat_nodes.nii.gz $corticalNodeMask");

}

