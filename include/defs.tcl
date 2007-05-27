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

##
## default values
##

# location of files with TC descriptions and extension we should recognize
set TC_DESCR_DIR "testcases"
set TC_DESCR_EXT "tc"

# logs storage location
set LOG_DIR "./"

# location of files with board device descriptions and their extension
set DEVICE_DESCR_DIR "devices"
set DEVICE_DESCR_EXT "tgt"

# name of the common (shared) device definition
set DEVICE_COMMON_NAME "_common"
set DEVICE_COMMON_FILE "$DEVICE_COMMON_NAME.$DEVICE_DESCR_EXT"

# location of files with config descriptions
set CONFIG_DESCR_DIR "config"
set CONFIG_DESCR_EXT "cfg"
# name of the default config section
set CONFIG_DEFAULT_NAME "_default"

# default timeout for response to come (in sec)
set TIMEOUT 10
