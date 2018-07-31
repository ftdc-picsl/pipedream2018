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

my $crossSectionalDTI_BaseDir = "/data/grossman/pipedream2018/crossSectional/dti";

my $templateDir = "/data/grossman/pipedream2018/templates/OASIS";

my $groupTemplate = "${templateDir}/OASIS/T_template0.nii.gz";

my $groupTemplateMask = "${templateDir}/T_template0_BrainCerebellumMask.nii.gz";

my $templateToMNI_WarpRoot = "${templateDir}/MNI152/T_template0_ToMNI152";

my $mniTemplate ="${templateDir}/MNI152/MNI152_T1_1mm_brain.nii.gz";

my $mniTemplateMask = "${templateDir}/MNI152/MNI152_1mm_brainMask.nii.gz";

my $outputBaseDir = "";

my $antsLongCT_BaseDir = "";

my $antsPath = "/data/grossman/pipedream2018/bin/ants/bin/";

my $caminoDir = "/data/grossman/pipedream2018/bin/camino/bin";

my $cores=1;
my $ram="6";
my $submitToQueue=1;

my $usage = qq{

  $0  
      --subject
      --antslongct-base-dir
      --output-base-dir
     
      [ options ]

  Required args:

   --subject
     Subject ID

   --antslongct-base-dir
     where ants longitudinal CT output exists as antslongct-base-dir/subject

   --output-base-dir
     Base dir for output, output-base-dir/subject will be created

  Options:

   --timepoints  
     Timepoint(s) to process. If no time points are provided, it means process all available timepoints.

   --qsub
     Submit processing jobs to qsub (default = $submitToQueue).

   --ram
     Amount of RAM to request, in G (default = $ram).

   --cores
     CPU cores to request (default = $cores).


  Hard-coded settings:

  Cross-sectional DTI data is read from:

    ${crossSectionalDTI_BaseDir} 

  Group template:
  
    $groupTemplate

  Standard template:
   
    $mniTemplate

  Output:

    See processScanDTILong.pl for details of output. This script is a wrapper that sets up I/O and logs for running processScanDTILong.pl.

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
	    "antslongct-base-dir=s" => \$antsLongCT_BaseDir,
	    "output-base-dir=s" => \$outputBaseDir
	    
    )
    or die("Error in command line arguments\n");

my $qVmem = "${ram}G";

# set Camino memory limit
my $caminoHeapSize = $ram * 900;

my $numTimepoints = scalar(@timepoints);

if ($numTimepoints == 0) {
    @timepoints = `ls ${crossSectionalDTI_BaseDir}/${subject}`;

    chomp @timepoints;

    $numTimepoints = scalar(@timepoints);

    if ($numTimepoints == 0) {
	print "\n  No DTI data to process for $subject\n";
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
    
    my $inputDTI_Dir="${crossSectionalDTI_BaseDir}/${subject}/${tp}/";

    # Find output root from antsLongCT - depends on input naming

    my $tpAntsCTDir = `ls -d ${antsLongCT_BaseDir}/${subject}/* | grep "_${tp}_"`;

    chomp $tpAntsCTDir;

    if (! -d "$tpAntsCTDir") {
	print "\n  Incomplete or missing ANTs Long CT data for $subject $tp \n";
	next;
    }

    my $segmentation = `ls ${tpAntsCTDir} | grep "BrainSegmentation.nii.gz"`;

    chomp $segmentation;

    # Check for correct input
    if (! -f "${tpAntsCTDir}/$segmentation") {
	print "\n  Incomplete or missing ANTs Long CT data for $subject $tp \n";
	next;
    }

    $segmentation =~ m/(${subject}_${tp}_.*)BrainSegmentation.nii.gz/;

    my $antsCTFileRoot = $1;
    
    my $antsCTOutputRoot = "${tpAntsCTDir}/${antsCTFileRoot}";

    my $sstOutputRoot = "${antsLongCT_BaseDir}/${subject}/${subject}_SingleSubjectTemplate/T_template";


    if (! -d $inputDTI_Dir ) {
	print "\n  No DTI data for $subject $tp\n";
	next;
    }

    my $outputTP_Dir="${outputBaseDir}/${subject}/${tp}";     
    
    if (! -d $outputTP_Dir) {
	mkpath($outputTP_Dir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputTP_Dir\n\t";
	mkpath("${outputTP_Dir}/logs", {verbose => 0, mode => 0775}) or die "Cannot create output directory ${outputTP_Dir}/logs\n\t";
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

    my $scriptToRun="${outputTP_Dir}/scripts/dti_${subject}_${tp}_${runCounterFormatted}.sh";

    my $antsVersion = `cat ${antsPath}version.txt`;
    chomp $antsVersion;

    my $fh;

    open($fh, ">", $logFile);

    print $fh "ANTs version: ${antsVersion}\n\n";
    
    close($fh);

    open($fh, ">", $scriptToRun);
    
    # Set paths here so they can't get altered by user profiles
    
    print $fh qq{
export ANTSPATH=$antsPath

export PATH=${caminoDir}:${antsPath}:\${PATH}

export CAMINO_HEAP_SIZE=${caminoHeapSize};

${Bin}/processScanDTILong.pl --input-dir $inputDTI_Dir --output-dir $outputTP_Dir --output-file-root ${subject}_${tp}_ --antslongct-timepoint-output-root $antsCTOutputRoot --antslongct-sst-output-root $sstOutputRoot --group-template $groupTemplate --group-template-mask $groupTemplateMask --standard-template $mniTemplate --standard-template-warp-root $templateToMNI_WarpRoot --standard-template-mask mniTemplateMask 

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



