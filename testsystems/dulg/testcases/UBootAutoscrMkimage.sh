#!/bin/bash
#
# Creates an example UBoot script image. Output is suitable for DULG.
# $1: board name (used to get the location to store the image)
#

echo 'bash$ mkimage -A ppc -O linux -T script -C none -a 0 -e 0 \'
echo '> -n "autoscr example script" \'
echo "> -d example.script /tftpboot/$1/example.img"

mkimage -A ppc -O linux -T script -C none -a 0 -e 0 \
-n "autoscr example script" \
-d example.script /tftpboot/$1/example.img
