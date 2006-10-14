#!/bin/bash
#
# Creates an example UBoot script image. Output is suitable for DULG.
# $1: filename of UBoot source script
# $2: filename of the resultant image
#

echo 'bash$ mkimage -A ppc -O linux -T script -C none -a 0 -e 0 \'
echo '> -n "autoscr example script" \'
echo "> -d $1 $2"

mkimage -A ppc -O linux -T script -C none -a 0 -e 0 \
-n "autoscr example script" \
-d $1 $2
