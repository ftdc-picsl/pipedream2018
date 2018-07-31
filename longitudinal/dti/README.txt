DTI processing
---------------

Processing steps:

 - Alignment to T1, import brain mask to DWI space

 - Fit DT 

 - Concatenate warps, generate template space output


Run 

  ./processDTILong.pl

for a top-level wrapper

  ./processDTILong.pl and processScanDTILong.pl make use of cross-sectional output.

The idea is that the basic pre-processing should not change, but the brain mask and hence the alignment to the time point might change a bit. 
So the scripts re-compute the DT <-> T1 mapping and re-mask the tensor. Then the DT is resampled in the T1, SST, group template space.


Alternatively, the full DT pre-processing can be run on the longitudinal data using ./processDTIFull.pl (not tested, and uses more disk space). 
Avoid this unless you really need data and can't do it cross-sectionally first.


Connectivity
------------

The connectivity matrix is computed in the SST space with tracts defined from each time point. The average FA is used to mask
the JLF labels to create nodes of the connectivity graph.

Run 

  scripts/dti/sstAverageScalars.pl

to create the average FA etc for each subject. Then you can run

  scripts/dti/dtConnMatLongSubj.pl

