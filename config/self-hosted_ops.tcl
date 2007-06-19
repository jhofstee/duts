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

#
# Methods implementing operations on the target device in the self hosted environment
#

#
# manual power on/off
#
proc _device_power_on {} {
	global powered_on

	set powered_on "yes"
}

proc _device_power_off {} {
}

#
# direct connection to the target
#
proc _device_connect_target {} {

	global board_name cur_context

	p_banner " Please perform the following tasks:    "
	puts "\n 1. power on the target device\n\
	2. leave firmware with the ready prompt (this may require breaking autoboot\
	etc.)\n\
	3. disconnect from the console port (so DUTS can take over)\n"

	if ![ask_yesno "Please confirm the above steps were completed? "] {
		exit1
	}
	set cur_context "firmware"

	#set con_cmd "cu -l /dev/ttyS0 -s 115200"
	set con_cmd "/usr/bin/rlogin ts0 -l $board_name"

	if [catch {set sid [eval spawn -noecho $con_cmd]}] {
		p_err "couldn't spawn connecting command?!" 1
	}

	return $spawn_id
}

#
# method implementing connecting to the host (VL), it is only required for
# the remote VL set up, so systems with local VL may have it a no-op. returns
# spawn_id of the created process
# 
proc _device_connect_host {} {
}

proc _device_disconnect_target {} {
}

proc _device_disconnect_host {} {
}


proc is_powered_on {} {

	global powered_on

	set powered_on "yes"
	return 1
}

#
# returns device's current context [class], we assume console/control
# connection(s) established
#
proc _device_current_context {} {
	global console_con _context_firmware_prompt
	global _context_kernel_prompt _context_kernel_alt_prompt

	set kp1 $_context_kernel_prompt
	if [var_exists _context_kernel_alt_prompt] {
		set kp2 $_context_kernel_alt_prompt
	} else {
		set kp2 $kp1
	}

	set ctx "off"
	set spawn_id $console_con

	if [is_powered_on] {
		send -s " \r" 
		expect {
			timeout {
				p_err "timed out - context unknown..?!" 1
			}
			$_context_firmware_prompt {
				set ctx "firmware"
			}
			$kp1 {
				set ctx "kernel"
			}
			$kp2 {
				set ctx "kernel"
			}
			"login:" {
				if ![login_kernel "root" "root"] {
					p_err "context unknown..?!" 1
				}

				set ctx "kernel"
			}
		}
	}
	return $ctx
}
