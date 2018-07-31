#!/usr/bin/perl -w
#
# Wrapper script for calling processScanDTI.pl for some or all of a subject's data
#

use strict;
use FindBin qw($Bin);
use File::Path;
use File::Spec;
use File::Basename;
use Getopt::Long;


my $templateDir = "/data/grossman/pipedream2018/templates/OASIS";

my $template = "${templateDir}/T_template0_BrainCerebellum.nii.gz";

my $templateToMNI_WarpRoot = "${templateDir}/MNI152/T_template0_ToMNI152";

my $mniTemplate ="${templateDir}/MNI152/MNI152_T1_1mm_brain.nii.gz";

# Masks are used to mask deformed DT 
my $templateMask = "${templateDir}/T_template0_BrainCerebellumMask.nii.gz";

my $mniTemplateMask = "${templateDir}/MNI152/MNI152_1mm_brainMask.nii.gz";

my $inputBaseDir = "/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii";

my $outputBaseDir = "/data/grossman/pipedream2018/crossSectional/dti/";

my $antsCT_BaseDir = "/data/grossman/pipedream2018/crossSectional/antsct";

my $antsPath = "/data/grossman/pipedream2018/bin/ants/bin/";

my $caminoDir = "/data/grossman/pipedream2018/bin/camino/bin";

my $acqParamsDir = "/data/grossman/pipedream2018/metadata";

my $cores=1;
my $ram="4";
my $submitToQueue=1;
my $eddyCorrectMethod = "ants";

my $usage = qq{

  $0  
      --subject
     
      [ options ]

  Required args:

   --subject
     Subject ID


  Options:

   --timepoints  
     Timepoint(s) to process. If no time points are provided, it means process all available timepoints.

   --qsub
     Submit processing jobs to qsub (default = $submitToQueue).

   --ram
     Amount of RAM to request, in G (default = $ram).

   --cores
     CPU cores to request (default = $cores).

   --eddy-correct-method 
     Eddy correction method, either ANTs or FSL (default = $eddyCorrectMethod).
  

  Hard-coded settings:

  There are various hard-coded settings for software and other input. See the script and check these are correct.

  Output base directory:

    ${outputBaseDir} 

  T1, brain mask, and warps to template from AntsCT directory:
  
    ${antsCT_BaseDir}


  Output:

    See processScanDTI.pl for details of output. This script is a wrapper that sets up I/O and logs for running processScanDTI.pl.

};

if ($#ARGV < 0) {
    print $usage;
    exit 1;
}

my $subject = "";
my @timepoints = ();

GetOptions ("subject=s" => \$subject,
	    "timepoints=s{1,1000}" => \@timepoints,
	    "qsub=i" => \$submitToQueue,
	    "ram=s" => \$ram,
	    "cores=i" => \$cores,
            "eddy-correct-method=s" => \$eddyCorrectMethod
    )
    or die("Error in command line arguments\n");

my $qVmem = "${ram}G";

# set Camino memory limit
my $caminoHeapSize = $ram * 900;

my $numTimepoints = scalar(@timepoints);

if ($numTimepoints == 0) {
    @timepoints = `ls ${inputBaseDir}/${subject}`;

    chomp @timepoints;

    $numTimepoints = scalar(@timepoints);

    if ($numTimepoints == 0) {
	print "\n  No DWI data to process for $subject\n";
	exit 1;
    }
}

my $parallel="";

if ($cores > 1) {
    $parallel="-pe unihost $cores -binding linear:$cores"; 
}

# Submit each time point

for ( my $i=0; $i < $numTimepoints; $i++ ) {
    my $tp=$timepoints[$i];
    
    my $inputDWI_Dir="${inputBaseDir}/${subject}/${tp}/DWI";
    my $antsCT_OutputRoot="${antsCT_BaseDir}/${subject}/${tp}/${subject}_${tp}_";
    
    # Check for correct input
    if (! -f "${antsCT_OutputRoot}CorticalThickness.nii.gz") {
	print "\n  Incomplete or missing ANTsCT data for $subject $tp \n";
	next;
    }

    if (! -d $inputDWI_Dir ) {
	print "\n  No DWI data for $subject $tp\n";
	next;
    }

    # Quick check for some data
    my @bvecs = `ls ${inputDWI_Dir}/*.bvec 2> /dev/null`;

    if (scalar(@bvecs) == 0) {
	print "\n  No DTI data for $subject $tp\n";
	next;
    }

    # Match acqParams to protocol used for this DWI data
    $bvecs[0] =~ m/${subject}_${tp}_[0-9]{4}_(.*).bvec/;

    my $dwiProtocol = $1;

    my $acqParams = "${acqParamsDir}/${dwiProtocol}_acqp.txt";
    
    my $outputTP_Dir="${outputBaseDir}/${subject}/${tp}";     
    
    if (! -d $outputTP_Dir) {
	mkpath($outputTP_Dir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputTP_Dir\n\t";
    }
    if (! -d "${outputTP_Dir}/logs") { 	
      mkpath("${outputTP_Dir}/logs", {verbose => 0, mode => 0775}) or die "Cannot create output directory ${outputTP_Dir}/logs\n\t";
    }
    if (! -d "${outputTP_Dir}/scripts") {
      mkpath("${outputTP_Dir}/scripts", {verbose => 0, mode => 0775}) or die "Cannot create output directory ${outputTP_Dir}/scripts\n\t";
    }
    
    # increment log counter as needed
    my $runCounter=1;
    
    my $runCounterFormatted = sprintf("%03d", $runCounter);
    
    my $logFile="${outputTP_Dir}/logs/dti_${subject}_${tp}_log${runCounterFormatted}.txt";
    
    while (-f $logFile) {

	$runCounter = $runCounter + 1;
	
	$runCounterFormatted = sprintf("%03d", $runCounter);

	$logFile="${outputTP_Dir}/logs/dti_${subject}_${tp}_log${runCounterFormatted}.txt";
    }

    if ($runCounter > 1) {
        print "  Some output exists for ${subject} ${tp}, resubmitting\n";
    }

    my $scriptToRun="${outputTP_Dir}/scripts/dti_${subject}_${tp}_${runCounterFormatted}.sh";

    my $antsVersion = `cat ${antsPath}version.txt`;
    chomp $antsVersion;

    my $fh;

    open($fh, ">", $logFile);

    print $fh "ANTs version: ${antsVersion}\n\n";
    
    close($fh);

    open($fh, ">", $scriptToRun);
    
    # Set paths here so they can't get altered by user profiles
    
    # Just ANTs and Camino; FSL version is hard coded into eddy scripts
    
    print $fh qq{
export ANTSPATH=$antsPath

export PATH=${caminoDir}:${antsPath}:\${PATH}

export CAMINO_HEAP_SIZE=${caminoHeapSize};

${Bin}/processScanDTI.pl --input-dir $inputDWI_Dir --output-dir $outputTP_Dir --output-file-root ${subject}_${tp}_ --acq-params $acqParams --eddy-correct-method $eddyCorrectMethod --antsct-output-root $antsCT_OutputRoot --template $template --standard-template $mniTemplate --standard-template-warp-root $templateToMNI_WarpRoot --template-mask $templateMask --standard-template-mask $mniTemplateMask
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



