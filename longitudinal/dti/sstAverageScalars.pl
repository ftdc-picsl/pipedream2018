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

# Hard code this for now
my $backgroundMD = 7E-4;


my $usage = qq{

  $0 
     --subject
     --longdt-base-dir
     --antslongct-base-dir
     [options]

  Required args

   --subject
     Subject ID.

   --antslongct-base-dir 
     Base antsLongCT dir for T1 data.
  
   --longdt-base-dir
     Base longitudinal DTI dir. All time points under baseDir/subject/ will be processed.


  Options  

   --save-tensor
     If 1, save the diffusion tensor (default = 0).

  Scalar metrics are computed after averaging

    FA - fractional anisotropy
    MD - Mean diffusivity (L1 + L2 + L3) / 3 
    RD - Radial diffusivity (L2 + L3) / 2

};


if ($#ARGV < 0) {
    print $usage;
    exit 1;
}

# Require all of these
my ($subject, $antsLongCTBaseDir);

# Options have default settings
my $saveTensor = 0;

my $inputBaseDir = "";

GetOptions ("subject=s" => \$subject,
	    "antslongct-base-dir=s" => \$antsLongCTBaseDir,
	    "longdt-base-dir=s" => \$inputBaseDir,
	    "save-tensor=i" => \$saveTensor
    )
    or die("Error in command line arguments\n");

# Set to 1 to delete intermediate files after we're done
# Has no long term effect if using qsub since files get cleaned up anyhow
my $cleanup=1;

my $outputDir = "${inputBaseDir}/${subject}/singleSubjectTemplate";

if (! -d $outputDir ) { 
  mkpath($outputDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputDir\n\t";
}

my $tmpDir = "";

my $tmpDirBaseName = "${subject}_sstAverageDT";

if ( !($sysTmpDir && -d $sysTmpDir) ) {
    $tmpDir = $outputDir . "/${tmpDirBaseName}";
}
else {
    # Have system tmp dir
    $tmpDir = $sysTmpDir . "/${tmpDirBaseName}";
}

# Gets removed later, so check we can create this and if not, exit immediately
mkpath($tmpDir, {verbose => 0, mode => 0755}) or die "Cannot create working directory $tmpDir (maybe it exists from a previous failed run)\n\t";

my $outputRoot = "${outputDir}/${subject}_Average";

my $sst = "${antsLongCTBaseDir}/${subject}/${subject}_SingleSubjectTemplate/T_template0.nii.gz";
my $sstMask = "${antsLongCTBaseDir}/${subject}/${subject}_SingleSubjectTemplate/T_templateBrainExtractionMask.nii.gz";

chomp(my @tps = `ls ${inputBaseDir}/$subject | grep -v singleSubjectTemplate`);

foreach my $tp (@tps) {

    my $dtMoving = "${tmpDir}/${subject}_${tp}_dtMasked.nii.gz";

    # Create temp moving DT image with background set to isotropic tensor to avoid edge interpolation problems
    system("${antsPath}ImageMath 3 $dtMoving TensorMask ${inputBaseDir}/${subject}/${tp}/dt/${subject}_${tp}_DT.nii.gz ${inputBaseDir}/${subject}/${tp}/dt/${subject}_${tp}_BrainMask.nii.gz $backgroundMD");
 
    # Distortion correction warp to T1
    my $distCorrWarpString = "-t ${inputBaseDir}/${subject}/${tp}/distCorr/${subject}_${tp}_DistCorr1Warp.nii.gz -t ${inputBaseDir}/${subject}/${tp}/distCorr/${subject}_${tp}_DistCorr0GenericAffine.mat";

    # warp from T1 to SST
    chomp( my $t1ToSSTWarpFile = `ls ${antsLongCTBaseDir}/${subject}/${subject}_${tp}_*/*SubjectToTemplate1Warp.nii.gz`);
    chomp( my $t1ToSSTAffineFile = `ls ${antsLongCTBaseDir}/${subject}/${subject}_${tp}_*/*SubjectToTemplate0GenericAffine.mat`);

    my $t1ToSSTWarpString = "-t $t1ToSSTWarpFile -t $t1ToSSTAffineFile";
 
    my $dtSST = "${tmpDir}/${subject}_${tp}_DTNormalizedToSST.nii.gz";

    my $compositeWarp = "${tmpDir}/${subject}_${tp}_DTToSSTWarp.nii.gz";

    system("${antsPath}antsApplyTransforms -d 3 -e 2 -r $sst $t1ToSSTWarpString $distCorrWarpString -i $dtMoving -o $dtSST");

    system("${antsPath}antsApplyTransforms -d 3 -e 2 -r $sst $t1ToSSTWarpString $distCorrWarpString -i $dtMoving -o [${compositeWarp}, 1]");

    system("${antsPath}ImageMath 3 $dtSST TensorMask $dtSST $sstMask 0");
    
    system("${antsPath}ReorientTensorImage 3 $dtSST $dtSST $compositeWarp");
    
}

my $avgDT = "${tmpDir}/${subject}_AverageDT.nii.gz";

system("${antsPath}AverageTensorImages 3 $avgDT 0 ${tmpDir}/${subject}_*_DTNormalizedToSST.nii.gz");

createScalarImages($avgDT, $outputRoot, "");


if ($saveTensor) {
    system("cp $avgDT ${outputRoot}DT.nii.gz");
}


# cleanup

if ($cleanup) {
    system("rm -f ${tmpDir}/*");
    system("rmdir $tmpDir");
}



#
# createScalarImages($dt, $outputRoot, $outputSuffix)
#
# Computes ${outputRoot}[FA, MD, RD]${outputSuffix}
#
sub createScalarImages {

    my ($dt, $outputRoot, $outputSuffix) = @_;

    system("${antsPath}ImageMath 3 ${outputRoot}FA${outputSuffix}.nii.gz TensorFA $dt");
    system("${antsPath}ImageMath 3 ${outputRoot}MD${outputSuffix}.nii.gz TensorMeanDiffusion $dt");
    system("${antsPath}ImageMath 3 ${outputRoot}AD${outputSuffix}.nii.gz TensorAxialDiffusion $dt");
    system("${antsPath}ImageMath 3 ${outputRoot}RD${outputSuffix}.nii.gz TensorRadialDiffusion $dt");
    system("${antsPath}ImageMath 3 ${outputRoot}RGB${outputSuffix}.nii.gz TensorColor $dt");
    
}
