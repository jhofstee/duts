#
# (C) Copyright 2008-2011 Detlev Zundel <dzu@denx.de>, DENX Software Engineering
# (C) Copyright 2006, 2007 Rafal Jaworowski <raj@semihalf.com> for DENX Software Engineering
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

# this script implements specific behaviours of DENX VL
#
# methods are responsible for error handling, exiting if fatal etc.
#
# NOTICE: this file is supposed to only contain procs definitions and not any
# other code directly executed
#

#TODO add dry_run case everywhere


#
# method implementing powering on the $board_name device
#
proc _device_power_on {} {
	global board_name
	set cmd "/usr/local/bin/remote_power"

	if [catch {set output [exec $cmd $board_name "on" 2>@1]}] {
		p_err "cannot execute '$cmd'"
		return 0
	}
	p_verb "powered on, OK"
	return 1
}


#
# method implementing powering off $board_name
#
proc _device_power_off {} {
	global board_name
	set cmd "/usr/local/bin/remote_power"

	if [catch {set output [exec $cmd $board_name "off" 2>@1]}] {
		p_err "cannot execute '$cmd'"
		return 0
	}
	p_verb "powered off, OK"
	return 1
}


#
# method implementing connection to the target in $board_name global
#
proc _device_connect_target {} {
	global console_con board_name target_connected

	if {$target_connected == "yes"} {
		return $console_con
	}

	set con_cmd "connect"

	expect "*"
	#TODO check if not already connected (connected global)
	if [catch {spawn -noecho $con_cmd $board_name}] {
		p_err "couldn't spawn 'connect'?!" 1
	}

	set target_connected "yes"
	set console_con $spawn_id

	expect {
		timeout {
			puts ""
			p_err "timed out during connection to target\
			'$board_name'?!" 1
		}
		"Unknown target:" {
			puts ""
			p_err "unknown target '$board_name'?!" 1
		}
		"Usage:" {
			puts ""
			p_err "no board name given?!" 1
		}
		# connect succeeds by echoing used command to connect.  Wait a little for error messages.
		-re "Connect to \"$board_name\" using command" {
			set timeout 1
			expect -re ".*Error.*|Connection closed" {
				puts ""
				p_err "target is in use: '$board_name'..." 1
			}
			set timeout 10
			p_verb "connection OK"
		}
	}
	return $console_con
}


proc _device_disconnect_target {} {
	global console_con target_connected

	p_verb "Closing device connection"
	if {$target_connected == "yes"} {
		close -i $console_con
		set target_connected "no"
	}
}

#
# checks if device is powered on, assume connection to host established for
# remote set up
#
proc is_powered_on {} {
	global board_name
	set cmd "/usr/local/bin/remote_power"

	if [catch {set output [exec $cmd $board_name "-l" 2>@1]}] {
		p_err "cannot execute '$cmd'"
		return 0
	}
	if {[regexp "ON$" $output]} {
		p_verb "Device is powered on"
		return 1
	} else {
		p_verb "Device has no power"
		return 0
	}
}


#
# returns device's current context [class], we assume console/control
# connection(s) established
#
proc _device_current_context {} {
	global console_con _context_firmware_prompt
	global _context_kernel_prompt _context_kernel_alt_prompt
	global timeout

	set kp1 $_context_kernel_prompt
	if [var_exists _context_kernel_alt_prompt] {
		set kp2 $_context_kernel_alt_prompt
	} else {
		set kp2 $kp1
	}

	set ctx "off"
	set spawn_id $console_con

	# FIXME recovery from Linux login should really be elsewhere as is context-specific

	set oldto $timeout
	set timeout 5

	# Flush any leftovers
	expect "*"

	if [is_powered_on] {
		send -s " \r"
		expect {
			timeout {
				p_err "timed out - assuming hang, will reset.."
				_device_power_off
				set ctx "off"
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
	set timeout $oldto
	return $ctx
}
