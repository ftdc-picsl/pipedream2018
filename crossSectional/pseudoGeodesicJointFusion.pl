#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Path;
use FindBin qw($Bin);

my $usage = qq {

  $0 <brainToLabel> <brainMask> <templateWarpToSubject> <templateAffineToSubject> <outputDir> <outputFileRoot>

  brainToLabel - brain extracted brain image

  brainMask - binary brain mask for subject

  templateWarpToSubject - warp from template to subject

  templateAffineToSubject - affine from template to subject

  outputDir - where to put output

  outputFileRoot - how to name output file

  The algorithm applies the N warps from the atlases to the template concatenated with the single 
  template to subject warp.

  [atlas1] -> [template] 
  [atlas2] -> [template]  -> [subject]
  [atlas3] -> [template]

  joint intensity fusion is then run on the atlases and labels in the subject space

};

if ($#ARGV < 0) {
  print $usage;
  exit 1;
} 

# If 1, run in qlogin or set tmpDir to something persistent before running
my $keepFiles = 0;

# template base directory
my $templateDir = "/data/grossman/pipedream2018/templates/";

my ($inputBrain, $brainMask, $templateWarpToSubject, $templateAffineToSubject, $outputDir, $outputFileRoot) = @ARGV;

my $doJIF = 0;

if ($#ARGV > 5) {
    $doJIF = $ARGV[6];
}

my ($antsPath, $tmpDir) = @ENV{'ANTSPATH', 'TMPDIR'};

if ( !($antsPath && -d $antsPath) ) {
  die("This program requires ANTSPATH to be set");
}

if ( !($tmpDir && -d $tmpDir) ) {
    $tmpDir = $outputDir . "/${outputFileRoot}templateMalfTmp";
}
else {
  $tmpDir = "${tmpDir}/${outputFileRoot}templateMalfTmp"; 
}

mkpath($tmpDir, {verbose => 0, mode => 0755}) or die "Cannot create working directory $tmpDir\n\t";

if ( !( -d $outputDir) ) {
  mkpath($outputDir, {verbose => 0, mode => 0755}) or die "Cannot create output directory $outputDir\n\t";
}

print "Placing working files in directory: $tmpDir\n";

my $brainToLabel="${tmpDir}/${outputFileRoot}brain.nii.gz";

my $brainMaskTmp = "${tmpDir}/${outputFileRoot}brainMask.nii.gz";

system("cp $brainMask $brainMaskTmp");

# Again try to gain speed by reading this from $tmpDir
$brainMask = $brainMaskTmp;

system("${antsPath}ImageMath 3 $brainToLabel m $inputBrain $brainMask");

my $oasis30TemplateMalfDir = "${templateDir}/OASIS/jlf/OASIS30/";

my @oasis30SubjectIDs = qw(1000 1001 1002 1003 1004 1005 1006 1007 1008 1009 1010 1011 1012 1013 1014 1015 1017 1018 1019 1036 1101 1104 1107 1110 1113 1116 1119 1122 1125 1128);

# Assume labels of the form ${id}.nii.gz ${id}_seg.nii.gz
# with warps malf${id}1Warp.nii.gz malf${id}0GenericAffine.mat

# run time choice of Malf labels
my $malfDir = $oasis30TemplateMalfDir;
my @malfSubjectIDs = @oasis30SubjectIDs;

my @grayImagesSubjSpace = ();
my @segImagesSubjSpace = ();

foreach my $malfSubj (@malfSubjectIDs) {

  # Step 1. Warp MALF brains and labels to subject space

  my $grayImage = "${malfDir}/${malfSubj}.nii.gz";
  my $segImage = "${malfDir}/${malfSubj}_seg.nii.gz";

  my $grayToTemplateWarp = "${malfDir}/${malfSubj}_ToTemplate1Warp.nii.gz";

  my $grayToTemplateAffine = "${malfDir}/${malfSubj}_ToTemplate0GenericAffine.mat";

  my $warpString = "-r $brainToLabel -t $templateAffineToSubject -t $templateWarpToSubject -t $grayToTemplateWarp -t $grayToTemplateAffine ";

  my $grayImageDeformed = "${tmpDir}/${malfSubj}_deformed.nii.gz";

  my $segImageDeformed = "${tmpDir}/${malfSubj}_segdeformed.nii.gz";

  system("${antsPath}antsApplyTransforms -d 3 -i $grayImage -o $grayImageDeformed $warpString");

  system("${antsPath}antsApplyTransforms -d 3 -i $segImage -o $segImageDeformed -n NearestNeighbor $warpString");

  system("${antsPath}ImageMath 3 $grayImageDeformed m $grayImageDeformed $brainMask");
  system("${antsPath}ImageMath 3 $segImageDeformed m $segImageDeformed $brainMask");

  push(@grayImagesSubjSpace, $grayImageDeformed);
  push(@segImagesSubjSpace, $segImageDeformed);

}


print "Running JIF \n";
   
my $cmd = "${antsPath}antsJointFusion -d 3 -v 1 -t $brainToLabel -x $brainMask -g " . join(" -g ",  @grayImagesSubjSpace) . " -l " . join(" -l ",  @segImagesSubjSpace) . " -o [ ${outputDir}/${outputFileRoot}PG_antsLabelFusionLabels.nii.gz, ${outputDir}/${outputFileRoot}PG_antsLabelFusionGray.nii.gz]";

print "\n$cmd\n";

system($cmd);
    
# Copy brain to output for easy evaluation
system("cp $brainToLabel ${outputDir}/${outputFileRoot}brain.nii.gz");

# Step 4. Clean up

if (!$keepFiles) {
  system("rm -rf $tmpDir");
}
