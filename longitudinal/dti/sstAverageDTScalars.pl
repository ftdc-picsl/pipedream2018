#!/usr/bin/perl -w
#
# Average deformed DTs in SST space
#


use strict;
use FindBin qw($Bin);
use File::Path;
use File::Spec;
use File::Basename;
use Getopt::Long;

my $antsPath = "/data/grossman/pipedream2018/bin/ants/bin/";

# Get the directories containing programs we need
my ($sysTmpDir) = $ENV{'TMPDIR'};

# Defaults for options mentioned in usage

my $usage = qq{

  $0 
     --dt-norm-dir
     --subject
     [options]

  Required args

   --subject
     Subject ID.

   --dt-norm-dir
     Path where the FA images to be averaged are in dtNormDir/subject/tp/subject_tp_FANormalizedToSST.nii.gz
     Output is in dtNormDir/subject/singleSubjectTemplate.

  Options  

   --mask
     Brain mask for the SST.

  Scalar metrics are averaged in the SST space, these are useful for masking / QC.

  This script computes the average scalars directly, rather than averaging the DT. It may not be as accurate
  but it does save disk space.

    DT - diffusion tensors
    FA - fractional anisotropy
    MD - Mean diffusivity (L1 + L2 + L3) / 3 = (AD + 2*RD) / 3
    RGB - Tensor principal direction color image modulated by FA


};


if ($#ARGV < 0) {
    print $usage;
    exit 1;
}

# Require all of these
my ($subject, $dtNormDir);

# Options have default settings
my $sstMask = "";
my $saveTensor = 0;

GetOptions ("subject=s" => \$subject,
	    "dt-norm-dir=s" => \$dtNormDir,
	    "mask=s" => \$sstMask
    )
    or die("Error in command line arguments\n");


# Set to 1 to delete intermediate files after we're done
# Has no long term effect if using qsub since files get cleaned up anyhow
my $cleanup=1;


my $outputDir = "${dtNormDir}/${subject}/singleSubjectTemplate";

if (! -d $outputDir ) { 
  mkpath($outputDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputDir\n\t";
}


# Check input

my @tps = `ls ${dtNormDir}/$subject | grep -v singleSubjectTemplate`;

chomp @tps;


foreach my $scalar ("FA", "MD", "RD") {
    
    my $imageString = "";

    foreach my $tp (@tps) {
	$imageString = $imageString . " ${dtNormDir}/${subject}/${tp}/dtNorm/${subject}_${tp}_${scalar}NormalizedToSST.nii.gz";
    }
}


my $avgDT = "${tmpDir}/${subject}_AverageDT.nii.gz";

my $cmd = "${antsPath}AverageTensorImages 3 $avgDT 0 $imageString";

system("$cmd");

# Check average is successfully computed
if (! -f $avgDT) {
    die("\n  Error computing average DT from $imageString");
}


my $outputRoot = "${outputDir}/${subject}_Average";

createScalarImages($avgDT, $outputRoot, "");

if ($saveTensor) {
    system("cp $avgDT ${outputRoot}DT.nii.gz");
}

# cleanup

if ($cleanup) {
    system("rm -f ${tmpDir}/*");
    system("rmdir $tmpDir");
}

