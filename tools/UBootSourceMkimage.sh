#!/bin/bash
#
# (C) Copyright 2006, 2007 DENX Software Engineering
#
# Author: Rafal Jaworowski <raj@semihalf.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#

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
