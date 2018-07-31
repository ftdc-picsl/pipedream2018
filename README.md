# pipedream2018

WIP to centralize all scripts for pipedream2018 processing. 

Basic organization:

  auto/

Automated processing scripts called from cron jobs. These are used to convert new dicom data 
and submit T1 and DT data each week to the cross-sectional pipelines.

These scripts must be run by the mgrossman user


  crossSectional/

Cross-sectional antsCT.


  longitudinal/

Longitudinal antsCT.


## Dependencies 

### ANTs 

/data/grossman/pipedream2018/bin/ants/bin

Built from source

Version c95e77abe72b0df5679e4728787b87489595517e


### Camino 

/data/grossman/pipedream2018/bin/camino/bin

Built from source

Version 37ef03b7045e2c296f15f8ba98183c1980d4b38a


### R

/data/grossman/pipedream2018/bin/R/R-3.4.3/bin/R


### QuANTs (unstable)

/data/grossman/pipedream2018/bin/QuANTs


### Pipedream

/data/jet/grosspeople/Volumetric/SIEMENS/pipedream2014/bin/pipedream

Stable but obsolete, needs to be replaced by wrapper to dcm2niix

Used for dicom conversion in the automated scripts
