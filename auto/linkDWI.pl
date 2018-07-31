#!/usr/bin/perl -w

use File::Path;

use strict;

my $baseDir = "/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii";

if ($#ARGV < 0) {
  print " 
  $0 <subject> <tp> 

";
  exit 1;
}

my ($subj, $tp) = @ARGV;

if (! -d "${baseDir}/${subj}/${tp}/rawNii") {
  print " No output in ${baseDir}/${subj}/${tp}\n";
  exit 1;
}

my @bvecs = `ls ${baseDir}/${subj}/${tp}/rawNii | grep .bvec`;

chomp @bvecs;

if ($#bvecs < 0) {
  print "  No DWI data for $subj $tp\n";
  exit 1;
}

my $dwiDir = "${baseDir}/${subj}/${tp}/DWI";

mkpath "$dwiDir";

chdir "$dwiDir";

foreach my $bvec (@bvecs) {
  my $bval = $bvec;
  
  $bval =~ s/\.bvec$/.bval/;

  my $data = $bvec;

  $data =~ s/\.bvec$/.nii.gz/;
   

  # Relative paths so these links will (hopefully) survive a move of the whole tree
  foreach my $file ($bvec, $bval, $data) {
    if (! -e $file) { # -e not -f because we're checking links
      system("ln -s ../rawNii/$file .");
    }
  }
} 

chdir "$baseDir";
