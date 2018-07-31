#!/usr/bin/perl -w

use File::Path;

use strict;

my $baseDir = "/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/subjectsNii";

# Hard code these since they change infrequently
my @t1Protocols = qw/ MPRAGE t1_mpr_AX_MPRAGE t1_mpr_ns_AXIAL T1W_MPR_0.7mm Sag_T1 Sag_MPRAGE Sagittal_MP-Rage MPRAGE_TI1100_ipat2 SAG_3D_MPRAGE t1_se_sag se_t1_sag MPRAGE_SAG_ISO MPRAGE_Repeat t1_axial SAG_MPRAGE_ISO SAG_T1_MPRAGE AX_3D_T1_FS_POST AXIAL_T1_NO_FC AX_T1_POST_WITH_FZ AXT1SE_CLEAR SGT1SE_CLEAR MPRAGE_SAGITTAL SAG_T1 MPRAGE_SAG se_t1_axial_post Sag_MPRAGE MPRage_Oblique_Cor_BW130 Sag_T1_ZZ_FILM_ALL Sag_T1__ZZ MPRAGE-10 MPRAGE-4 MPRAGE-5 MPRAGE-6 MPRAGE-7 MPRAGE_Repeat-3 MPRAGE_Repeat-4 MPRAGE_SAG-2 MPRAGE_SAG-3 MPRAGE_SAGITTAL-3 Sag_MPRAGE-12 Sag_MPRAGE-2 Sag_MPRAGE-6 Sag_MPRAGE-7 Sag_MPRAGE-8 t1_mpr_AX_MPRAGE-2 Sag_T1_ZZ_FILM_ALL-2_echo_1 se_t1_sag-2 t1_fl3d_COR-4_echo_1 trufi_3PLANE_LOC-1 SAG_3D_SPGR-2_echo_1 T1W_MPR_0.7mm MPRAGE_sag_moco3 Accelerated_Sagittal_MPRAGE T1_MPRAGE_Iso Accelerated_Sagittal_MPRAGE MPRAGE_GRAPPA2/;

if ($#ARGV < 0) {
  print " 
  $0 <subject> <tp> 

";
  exit 1;
}

my ($subj, $tp) = @ARGV;

if (! -d "${baseDir}/${subj}/${tp}/rawNii") {
  print " No output in ${baseDir}/${subj}/${tp} \n";
  exit 1;
}

my @images = `ls ${baseDir}/${subj}/${tp}/rawNii`;

chomp @images;

my $t1Dir = "${baseDir}/${subj}/${tp}/T1";

my @t1Images = ();

foreach my $image (@images) {
  foreach my $t1Protocol (@t1Protocols) {
    if ( $image =~ m/${t1Protocol}\.nii\.gz/) {
      push(@t1Images, $image);
    }
  }
}

if ($#t1Images < 0) {
  print " No T1 data for $subj $tp\n";
  exit 1;
}

mkpath "$t1Dir";

chdir "$t1Dir";

foreach my $t1Image (@t1Images) {

  # Relative paths so these links will (hopefully) survive a move of the whole tree
  if (! -e $t1Image ) { # -e not -f because we're checking links
    system("ln -s ../rawNii/$t1Image .");
  }
  
} 

chdir "$baseDir";
