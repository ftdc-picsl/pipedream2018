#!/usr/bin/perl -w

use strict;
use FindBin qw($Bin);

my $antsPath = "/data/grossman/pipedream2018/bin/ants/bin/";

my $dataBaseDir = "";
my $templateDir = "/data/grossman/pipedream2018/templates/OASIS";

my $subj = "";

my $outputBaseDir = "";

my @tps = ();


my $usage = qq {

  $0 <outputBaseDir> <inputNiiDir> <subject> <optionalTimepoint1> <optionalTimepoint2> <optionalTimepoint...>
  
  outputBaseDir - where the output will go

  inputNiiDir - where the un-processed niftis live

  subject - subject ID

  optionalTimepoint numbers - if specified, only the specified timepoints will be processed. If none specififed, will use all timepoints found in $dataBaseDir 

  Uses template in $templateDir


  Example: $0 /path/to/subjectsNii/ 123456 /data/somewhere/long

};

if (($#ARGV < 1)) {
  print "$usage\n";
  exit 1;
}

else {
  ($outputBaseDir, $dataBaseDir, $subj) = @ARGV[0..2];
}

if (($#ARGV == 2)) {
  @tps=`ls -d --color=none ${dataBaseDir}/${subj}/*/`;
  chomp @tps;
}
else {
  @tps = @ARGV[3..$#ARGV];
}

if ((scalar(@tps) < 2)) {
  print "No longitudinal data for $subj but that's ok now\n";
}

# TPs without T1 are a sign of trouble

my @t1ImagesWithPath = ();

foreach my $tp (@tps) {
   # my $t1 = `ls ${dataBaseDir}/${subj}/${tp}/T1/*MPRAGE* | tail -n1 `;
   my $t1 = `find ${dataBaseDir}/${subj}/${tp}/T1/ -name *nii.gz | tail -n1 `;
   chomp $t1;

   if (! -f "$t1" ) {
     print "Warning: Can't identify T1 data for $subj timepoint $tp\n";
   }
   else {   
     push(@t1ImagesWithPath, $t1);
   }
}
# print @t1ImagesWithPath; 
# exit 1;
if ( scalar(@t1ImagesWithPath) < 2 ) {
  print "No Longitudinal data for ${subj} but that's ok now\n";
}

my $logDir = "${outputBaseDir}/${subj}/logs";

if ( ! -d "${outputBaseDir}/${subj}" ) {
  system("mkdir -p ${logDir}");
  system("cp ${antsPath}/version.txt ${logDir}/${subj}_antsVersion.txt");
}
else {
  print "WARNING: output already exists for $subj\n";
 # exit 1
}

# Can't do everything fast; just not good enough. Initiate levels of fast
# 0 - Fast SST (old ANTS) but everything else slower for quality
# 1 - + Fast antsct to SST
# 2 - + Fast MALF cooking
# 3 - + Fast everything, won't be good  
my $quick = 2;


# Atlases and 6-class labels 
my $malfBrainDir = "/data/grossman/pipedream2018/templates/OASIS/jlf/OASIS30/";

my $malfSegDir = "/data/grossman/pipedream2018/templates/OASIS/jlf/OASIS30/";

# Do malf on the fly like this, replace with subset of subjects for speed or to remove persistent problem registrations
# my @malfSubjectIDs = qw(1000_3 1001_3 1002_3 1003_3 1004_3 1005_3 1006_3 1007_3 1008_3 1009_3 1010_3 1011_3 1012_3 1013_3 1014_3 1015_3 1017_3 1018_3 1019_3 1036_3 1101_3 1104_3 1107_3 1110_3 1113_3 1116_3 1119_3 1122_3 1125_3 1128_3);

# my @malfSubjectIDs = qw(1000_3 1001_3 1002_3 1003_3 1004_3 1005_3 1006_3 1007_3 1008_3 1009_3 1010_3 1011_3 1012_3 1013_3 1014_3 1015_3 1017_3 1018_3 1019_3 1036_3 1101_3 1104_3 1107_3 1110_3 1113_3 1116_3 1119_3 1122_3 1125_3 1128_3);
#
# Half selection - just take every other subject
# my @malfSubjectIDs = qw(1000_3 1002_3 1004_3 1006_3 1008_3 1010_3 1012_3 1014_3 1017_3 1019_3 1101_3 1107_3 1113_3 1119_3 1125_3);

# Or take the 15 oldest subjects (mean age 43, median 34) - exclude very oldest because WM is messed up
# 1001
# 1003
# 1005
# 1006
# 1013
# 1014
# 1019
# 1104
# 1107
# 1110
# 1113
# 1116
# 1119
# 1122
# 1125
# my @malfSubjectIDs = qw(1001_3 1003_3 1005_3 1006_3 1013_3 1014_3 1019_3 1104_3 1107_3 1110_3 1113_3 1116_3 1119_3 1122_3 1125_3);
my @malfSubjectIDs = qw(1001 1003 1005 1006 1013 1014 1019 1104 1107 1110 1113 1116 1119 1122 1125);
#my @malfSubjectIDs = qw(136_S_0086 136_S_0107 136_S_0186 136_S_0194 136_S_0196 136_S_0299 136_S_0300 136_S_0426 136_S_0429 136_S_0579);

my @malfGrayImages = ();
my @malfLabelImages = ();

foreach my $malfSubj (@malfSubjectIDs) {
  push(@malfGrayImages, $malfBrainDir . "/" . $malfSubj . ".nii.gz");
  push(@malfLabelImages, $malfSegDir . "/" . $malfSubj . "_segSixClass.nii.gz");
}

my $qScript = "${logDir}/antsLongCT_${subj}.sh";

my $antsLongCTCmd = "${Bin}/altBEAntsLongitudinalCorticalThickness.sh -d 3 -e ${templateDir}/T_template0.nii.gz -m ${templateDir}/T_template0_BrainCerebellumProbabilityMask.nii.gz -f ${templateDir}/T_template0_BrainCerebellumRegistrationMask.nii.gz -t ${templateDir}/T_template0_BrainCerebellum.nii.gz -v 0.25 -w 0.5 -n 0 -p ${templateDir}/priors/priors%d.nii.gz -q $quick -C 1 -y 1 -a " . join(" -a ", @malfGrayImages) . " -l " . join(" -l ", @malfLabelImages) . " -o ${outputBaseDir}/${subj}/${subj}_ " . join(" ", @t1ImagesWithPath);

open FILE, ">${qScript}";

print FILE qq{

export ANTSPATH=${antsPath}

$antsLongCTCmd

echo "
--- Warping thickness to MNI space ---
"

${Bin}/longCTtoMNI152.sh $subj ${outputBaseDir}

};

close FILE;

my $slots = 2;

my $qsubCmd="qsub -l h_vmem=10G,s_vmem=9.8G -pe unihost $slots -binding linear:$slots -S /bin/bash -cwd -j y -o ${logDir}/antsLongCT_${subj}.stdout $qScript";

open FILE, ">${logDir}/${subj}_qSubCall.sh";

print FILE "$qsubCmd\n";

close FILE;

# Capture job number just in case we want to find this job or track a job number to a particular subject
my $qsubOut = `$qsubCmd`;

$qsubOut =~ m/Your job ([0-9]+) /;

my $jobNumber = $1;

print "$qsubOut";

open FILE, ">${logDir}/${subj}_qSubJobNumber.sh";

print FILE "$jobNumber\n";

close FILE;

system("sleep 0.5");

