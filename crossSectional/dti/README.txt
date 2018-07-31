Use Pipedream / dicom2nii to get DTI data in Nii format.

Processing steps:

 - Merge the raw data into a single series

 - Extract B0 volumes and align to the first one

 - Alignment to T1, import brain mask to DWI space

 - Motion / distortion correct with FSL / eddy

 - Fit DT 

 - Concatenate warps, generate template space output


Run 

  ./processDTI.pl

for a top-level wrapper
