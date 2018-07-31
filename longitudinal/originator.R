#!/share/apps/R/R-3.2.5/bin/Rscript

library("optparse")
library("ANTsR")


##
## Gets the directory containing this script, either relative or absolute depending on how script was invoked
##
getBinDir <- function() {
    argv = commandArgs(trailingOnly = FALSE)
    binDir = dirname(substring(argv[grep("--file=", argv)], 8))
    return(binDir)
}


args = commandArgs(trailingOnly=TRUE)

option_list = list(
  make_option("--input", type="character", default=NULL, dest="movingFile",
              help="Input image file", metavar="character"),
  make_option("--output", type="character", default=NULL, dest="outputFile",   
              help="Output image file", metavar="character"),
  make_option("--template", type="character", default=NULL, dest="templateFile",
              help="template image", metavar="character")
); 
 
opt_parser = OptionParser(option_list=option_list,
  epilogue = "This script rigidly aligns the moving image to the template and uses that transform to find the template origin point in the moving image.
The purpose is to set the anatomical location of the origin somewhat consistently, which helps with template construction.");

if (length(args)==0) {
  print_help(opt_parser)
  quit(save = "no")
}

library("ANTsR")

opt = parse_args(opt_parser);

mov = antsImageRead(opt$movingFile)
template = antsImageRead(opt$templateFile)

warps = antsRegistration(fixed = template, moving = mov, typeofTransform = "Rigid", regIterations = c(20, 40, 0, 0))

origin = matrix(c(0,0,0), ncol = 3, nrow = 1)

originWarped = as.matrix(antsApplyTransformsToPoints(3, origin, transformlist = warps$fwdtransforms, whichtoinvert = c(F)))

originFix = antsImageClone(mov)

antsSetOrigin(originFix, as.numeric(antsGetOrigin(mov) - originWarped))

antsImageWrite(originFix, opt$outputFile)

