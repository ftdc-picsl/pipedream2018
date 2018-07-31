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

# CSV file containing Mindboggle label definitions
# These may be cortical or cortical + subcortial, but are assumed to be mindboggle
# This script is not general to different label schemes because it uses label > 100 
# as a cortical mask
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
      --antsct-base-dir
      --dt-base-dir
      [ options ]

  Required args:

   --subject
     Subject ID

   --antsct-base-dir 
     Base antsCT dir for T1 data
  
   --dt-base-dir
     Base DTI dir. There should be DT data for the time point(s) to be processed.

 
  Wrapper script for building matrices of connectivity. Calls dtConnMat.pl, see that script for additional options. 

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


  T1, brain mask, and segmentation images come from antsCT.

  The T1 image should be labeled using the pseudo-geodesic JLF.

  DT data is read from

    \${dt-base-dir}/subj/tp/

  The DTI preprocessing pipeline should have been run, such that dt/ and distCorr/ exist; 
  these will be used to do the tracking and transfer the results to T1 space.

  
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
my $antsCT_BaseDir = "";


my $subject = "";
my @timepoints = ();

GetOptions ("subject=s" => \$subject,
	    "timepoints=s{1,1000}" => \@timepoints,
	    "antsct-base-dir=s" => \$antsCT_BaseDir,
	    "dt-base-dir=s" => \$inputBaseDir,
	    "qsub=i" => \$submitToQueue,
	    "ram=s" => \$ram,
	    "cores=i" => \$cores
    )
    or die("Error in command line arguments\n");


my $sysTmpDir = $ENV{'TMPDIR'};

# Directory for temporary files that is deleted later
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

for ( my $i=0; $i < $numTimepoints; $i++ ) {
    my $tp = $timepoints[$i];

    # Output is in T1 space
    my $tpAntsCT_Root = "${antsCT_BaseDir}/${subject}/${tp}/${subject}_${tp}_";
    
    my $t1Brain = "${tpAntsCT_Root}ExtractedBrain0N4.nii.gz";

    my $t1Mask = "${tpAntsCT_Root}BrainExtractionMask.nii.gz";
    
    my $jlfLabels = "${tpAntsCT_Root}PG_antsLabelFusionLabels.nii.gz";

    # Use Atropos segmentation
    my $sixClassSeg = "${tpAntsCT_Root}BrainSegmentation.nii.gz";

    # Base dir containing DT stuff for this TP
    my $tpDTI_Dir = "${inputBaseDir}/${subject}/${tp}";

    my $segmentation = "${tpAntsCT_Root}BrainSegmentation.nii.gz";

    # Check for correct input
    if (! -f "$segmentation") {
	print "\n  Missing T1 segmentation for $subject $tp \n";
	next;
    }
    if (! -f "$jlfLabels") {
	print "\n  Missing JLF labels for $subject $tp \n";
	next;
    }

    my $dt = "${tpDTI_Dir}/dt/${subject}_${tp}_DT.nii.gz";

    if (! -f "$dt" ) {
	print "\n  No DT for $subject $tp\n";
	next;
    }

    my $tpOutputDir = "${outputBaseDir}/${subject}/${tp}/connMat";     

    if (-d $tpOutputDir) {
	print "\n  Output already exists for $subject $tp \n";
	next;
    }

    mkpath($tpOutputDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $tpOutputDir\n\t";

    my $dtMask = "${tpDTI_Dir}/dt/${subject}_${tp}_BrainMask.nii.gz";

    my $fa = "${tpDTI_Dir}/dt/${subject}_${tp}_FA.nii.gz";
    
    # Root for output we will create
    my $tpOutputRoot = "${tpOutputDir}/${subject}_${tp}_";

    # FA used to constrain exclusion. Only exclude if CSF && FA < threshold
    my $exclusionMask = "${tpOutputDir}/${subject}_${tp}_ExclusionMask.nii.gz";
    
    # Limit tracts to voxels inside brain mask
    # and additionally exclude those labeled CSF && FA < threshold
    my $csfPosterior = "${tpAntsCT_Root}BrainSegmentationPosteriors1.nii.gz";
	
    my $distCorrWarpRoot = "${tpDTI_Dir}/distCorr/${subject}_${tp}_DistCorr";

    my $faT1 = "${tpDTI_Dir}/dtNorm/${subject}_${tp}_FANormalizedToStructural.nii.gz";

    createExclusionMask($t1Mask, $csfPosterior, $faT1, $exclusionMask);
    
    my $graphNodes = "${tpOutputDir}/${subject}_${tp}_GraphNodes.nii.gz";
    
    createGraphNodes($jlfLabels, $labelDefs, $faT1, $graphNodes);
    
    my $logFile = "${tpOutputDir}/connMat_${subject}_${tp}_log.txt";
    
    my $scriptToRun = "${tpOutputDir}/connMat_${subject}_${tp}.sh";

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
    --reference-image $t1Brain \\
    --dist-corr-warp-root $distCorrWarpRoot \\
    --exclusion-image $exclusionMask \\
    --label-image $graphNodes \\
    --label-def $labelDefs \\
    --output-root ${tpOutputRoot} \\
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
	system("/bin/bash $scriptToRun >> $logFile 2>&1");
    }
    
    
} # for all timepoints


system("rm $tmpDir/*");
system("rmdir $tmpDir");


#
# Makes an exclusion (tract termination) mask from CSF and FA < 0.1. This truncates lines 
# that intersect CSF, but they may still be counted in the connectivity matrix if nodes 
# lie inside the exclusion mask.
#
# For example, CSF between cortical gyri might have a cortical Mindboggle label, or a 
# subcortical label (eg, caudate) might extend into CSF. This can result in false positive 
# connections.
#
# We could use this mask to curtail the labeled ROIs, but this risks introducing false 
# negatives, eg in atrophied cortex where the remaining GM is often misclassified.
#
# createExclusionMask($brainMask, $csf, $fa, $maskFile)
#
sub createExclusionMask  {

    my ($brainMask, $csfPosterior, $fa, $exclusionMask) = @_;

    my $tmpMask = "${tmpDir}/${subject}_exclusionMask.nii.gz";

    my $csfExclusionMask = "${tmpDir}/csfExclusionMask.nii.gz";

    system("${antsPath}ThresholdImage 3 $csfPosterior $csfExclusionMask 0.5 1.1");

    my $faThresh = "${tmpDir}/faExclusionMask.nii.gz";

    system("${antsPath}ThresholdImage 3 $fa $faThresh 0 0.09999");

    system("${antsPath}ImageMath 3 $tmpMask m $csfExclusionMask $faThresh");

    # Also exclude anything outside the brain mask
    my $brainMaskInv = "${tmpDir}/brainMaskInv.nii.gz";

    system("${antsPath}ThresholdImage 3 $brainMask $brainMaskInv 0 0.5");

    system("${antsPath}ImageMath 3 $tmpMask + $tmpMask $brainMaskInv");

    system("${antsPath}ThresholdImage 3 $tmpMask $tmpMask 1 Inf");
    
    # Copy final exclusion mask
    system("cp $tmpMask $exclusionMask");

}


#
# Makes the graph nodes in the T1 space. FA is used to remove any voxel that is labeled cortex
# but has FA >= 0.25.
# 
# Small clusters of FA >= 0.25 are ignored, to avoid noise at the edge of the
# brain eating into the cortical labels.
#
# createSubjectGraphNodes($jlfLabels, $labelDef, $fa, $nodeFile)
#
sub createGraphNodes {

    my ($jlfLabels, $labelDef, $fa, $nodeFile) = @_;

    system("${caminoDir}/conmat -outputroot ${tmpDir}/conmat_ -targetfile $jlfLabels -targetnamefile $labelDef -outputnodes");

    # This mask is created in several steps, the end result being that it's 1 if the voxel has a cortical label but is probably
    # WM. Hence it is used to remove such voxels from the final nodes
    my $corticalNodeMask = "${tmpDir}/corticalNodeMask.nii.gz";
 
    system("${antsPath}ThresholdImage 3 ${tmpDir}/conmat_nodes.nii.gz $corticalNodeMask 100 Inf");
 
    my $faMask = "${tmpDir}/faMask.nii.gz";

    system("${antsPath}ThresholdImage 3 $fa $faMask 0.25 Inf");

    # Get rid of junk FA around the edge of the brain, take large connected components only
    system("${antsPath}LabelClustersUniquely 3 $faMask $faMask 10000");
    
    system("${antsPath}ThresholdImage 3 $faMask $faMask 1 Inf");
    
    system("${antsPath}ImageMath 3 $corticalNodeMask m $faMask $corticalNodeMask");

    system("${antsPath}ThresholdImage 3 $corticalNodeMask $corticalNodeMask 1 1 0 1");

    system("${antsPath}ImageMath 3 $nodeFile m ${tmpDir}/conmat_nodes.nii.gz $corticalNodeMask");

}
