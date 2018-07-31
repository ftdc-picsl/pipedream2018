#!/bin/bash 

if [[ $# -eq 0 ]]; then
  echo " 

  `basename $0` -i <data> -o <output> [options]


  Required args:

  -i : input is a 4D image, usually DWI or BOLD.

  -o : output file, usually .gif, but you can try .avi or other animation format supported by ImageMagick.

  Options

  -a : slice axis (default = 2), slice normal to 0 = x, 1 = y, 2 = z. This slices in the voxel space.

  -c : a crop window (default = 90), expressed as a percentage of the original slice area. Set to 100 to disable cropping.

  -d : the delay between frames of the animation, in 100ths of a second (default = 25).

  -f : flip the slices, n(ot at all), or in x, y, or xy (default = y).
 
  -m : mask image to be applied to the data before animation. Decreases GIF file size.
  
  -n : Also output a nifti volume of the slices 1/0 (default = 0)
  
  -p : upper range for contrast. The intensities on each slice will be mapped to a 16-bit range, set this to clip slice intensity by percentile before mapping (default = 99.5%).

  -s : slice number, from 0 to [number of slices] - 1, or a percentage (default = 45%, or centroid of the mask)

  -z : final size of the gif, in pixels (default=700). If the slice is not square, the longer axis is scaled to this value.

  Requires: ANTs, c3d, ImageMagick.

"

exit 1

fi

data=""
output=""
sliceDim=2

cropPercent=90
delay=25
flipAxes="y"
mask=""
outputNifti=0
sliceNum="" # if blank, determine from data
stretchUpper="99.5%"
windowSize=700

antsExe=`which ExtractSliceFromImage`

if [[ -z "$antsExe" ]]; then
  echo " 
  Missing required program: ExtractSliceFromImage (part of ANTs)
"
exit 1
fi 

c3dExe=`which c3d`

if [[ -z "$c3dExe" ]]; then
  echo "
  Missing required program: c3d
"
exit 1
fi

imageMagickExe=`which convert`

if [[ -z "$imageMagickExe" ]]; then

echo "
  Missing required program: convert (part of ImageMagick)
"
exit 1
fi

while getopts "a:c:d:f:i:m:n:o:s:z:" OPT
  do
  case $OPT in
      a)  # Slice dimension, 0 1 2
   sliceDim=$OPTARG
   ;;
      c)  # Crop percent
   cropPercent=$OPTARG
   ;;
      d)  # animation frame delay
   delay=$OPTARG
   ;;
      f)  # flip axes
   flipAxes=$OPTARG
   ;;
      i)  # input image
   data=$OPTARG
   ;;
      m) # brain mask
   mask=$OPTARG
   ;;
      n) # nifti output
   outputNifti=$OPTARG
   ;;
      o)  # output
   output=$OPTARG
   ;;
      p) # Stretch upper
   stretchUpper=$OPTARG
   ;;
      s) # slice number
   sliceNum=$OPTARG
   ;;
      z)
   windowSize=$OPTARG
   ;;
     \?) # getopts issues an error message
   exit 1
   ;;
  esac
done

if [[ -z $sliceNum ]]; then
  if [[ -f $mask ]]; then
    centroidSlices=`c3d $mask -dup -centroid | perl -n -e 'if ($_ =~ m/CENTROID_VOX \[([0-9]+\.[0-9]+), ([0-9]+\.[0-9]+), ([0-9]+\.[0-9]+)\]/) { printf("%d %d %d", $1, $2, $3); }'`;
    sliceNum=`echo $centroidSlices | cut -d ' ' -f $((sliceDim + 1))`
  else
    sliceNum="45%"
  fi
fi

inputImageName=`basename ${data%.nii.gz}`

imageTmpDir=${TMPDIR}/${inputImageName}

if [[ ! -d "$TMPDIR" ]]; then
  imageTmpDir="/tmp/${inputImageName}"
fi

mkdir -p $imageTmpDir

sliceImage=${imageTmpDir}/slices_${i}.nii.gz

# Gets the same slice from each DWI, and outputs as a single 3D image
ExtractSliceFromImage 4 $data $sliceImage $sliceDim $sliceNum

niftiOutputString=""

if [[ $outputNifti -gt 0 ]]; then
  niftiOutputString="-omc ${output%.*}.nii.gz"
fi

# Now convert to a stack of PNGs
if [[ -f $mask ]]; then

  sliceLetter="z"

  if [[ $sliceDim -eq 0 ]]; then
    sliceLetter="x"
  elif [[ $sliceDim -eq 1 ]]; then
    sliceLetter="y"
  fi   

  c3d $mask -slice $sliceLetter $sliceNum -popas mask $sliceImage -slice z 0:100% -foreach -as theSlice -push mask -copy-transform -push theSlice -multiply -stretch 0 $stretchUpper 0 65534 -clip 0 65534 -endfor -type ushort -oo ${imageTmpDir}/slice_%03d.png $niftiOutputString

else

  c3d $sliceImage -slice z 0:100% -foreach -stretch 0 $stretchUpper 0 65534 -clip 0 65534 -endfor -type ushort -oo ${imageTmpDir}/slice_%03d.png $niftiOutputString

fi

# Crop background
for png in `ls ${imageTmpDir}/slice_*.png`; do
  convert $png -gravity Center -crop ${cropPercent}x${cropPercent}%+0+0 +repage $png
done

# Determine flip operation
flipCmd=""

if [[ "$flipAxes" == "x" ]]; then
  flipCmd="-flop"
elif [[ "$flipAxes" == "y" ]]; then 
  flipCmd="-flip"
elif [[ "$flipAxes" == "xy" ]]; then
  flipCmd="-flip -flop"
fi

convert -delay $delay -loop 0 -gravity Center -scale ${windowSize}x${windowSize} $flipCmd ${imageTmpDir}/slice_*.png ${output}

rm $imageTmpDir/*
