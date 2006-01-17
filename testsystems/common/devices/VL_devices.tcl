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
# if remote, assume connection to the host is established
#
proc _device_power_on {} {

	global board_name remote send_slow control_con

	set cmd "/usr/local/bin/remote_power"

#p_banner "powering ON"

	if {$remote == "yes"} {
		if {$control_con == ""} {
			p_err "no spawn_id of the control connection" 1
		}
		set spawn_id $control_con
		send -s "$cmd $board_name on\r"
	} else {
		# we're local on VL host so need to spawn the power_on process
		if [catch {spawn -noecho $cmd $board_name "on"}] {
			p_err "couldn't spawn '$cmd'" 1
		}
	}

	expect {
		timeout {
			 p_err "timed out while trying to power on the\
			 device?!" 1
		}
		"ERROR" {
			p_err "couldn't power on the device?!" 1
		}
		"Power on" {
			p_verb "powered on, OK"
		}
	}
	expect eof
}


#
#
#
proc _device_power_off {} {
}


#
# method implementing connection to the target in $board_name global
#
# for remote operation (via host - VL) we first connect to the host and then
# to the target. returns spawn_id of the process connected to the target
#
proc _device_connect_target {} {
	global remote board_name send_slow

	set send_slow {1 .050}
	set con_cmd "connect"
	
	expect "*"
	if {$remote == "yes"} {

		# we're remote so a connection to the host must be established
		set spawn_id [_device_connect_host] 
		send -s "$con_cmd $board_name\r"

	} else {
#TODO check if not already connected (connected global)	
		# we're locally in the VL so need to spawn "connect" command
		if [catch {spawn -noecho $con_cmd $board_name}] {
			p_err "couldn't spawn 'connect'?! Maybe -r option\
			(remote VL) needed..?" 1
		}
		
	}
	# TODO when the port is occupied by another connection it is not
	# reliably detected and handled

	#		"Error" {
	#			p_err "XXXXXX"
	#			exit1
	#		}
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
		"using command"	{
			p_verb "connection OK"
		}
	}
	return $spawn_id
}


#
# method implementing connecting to the host (VL), it is only required for
# the remote VL set up, so systems with local VL may have it a no-op. returns
# spawn_id of the created process
# 
proc _device_connect_host {} {

	set ssh_cmd "/usr/bin/ssh"
	set ssh_exp "raj]"
	set host "pollux"

	if [catch {spawn $ssh_cmd $host}] {
		p_err "couldn't spawn SSH?!" 1
	}

#TODO is current timeout period ok?
	expect {
		timeout {
			p_err "timed out while connecting to host '$host'" 1
		}
		$ssh_exp {
			p_verb "connection to host established"
		}
	}
	return $spawn_id
}


proc _device_disconnect_target {} {
}

proc _device_disconnect_host {} {
}


#
# checks if device is powered on, assume connection to host established for
# remote set up
#
proc is_powered_on {} {

	global remote control_con board_name
	
	set cmd "/usr/local/bin/remote_power"
	set rv 0

	if {$remote == "yes"} {
		set spawn_id $control_con
		send -s "$cmd $board_name -l\r"
	} else {
		if [catch {spawn $cmd $board_name "-l"}] {
			p_err "couldn't spawn '$cmd'" 1
		}
	}

	expect {
		timeout {
			p_err "timed out while checking if powered on" 1
		}
		"ON" {
			set rv 1
		}
		"off" {
		}
	}
#	p_verb "power status: $rv"
	return $rv
}

#
# returns device's current context [class], we assume console/control
# connection(s) established
#
proc _device_current_context {} {
	global remote console_con _context_firmware_prompt
	global _context_kernel_prompt connected

	set ctx "off"
	set spawn_id $console_con

#TODO recover from Linux login should really be elsewhere as is context-specific

	if [is_powered_on] {
		send -s " \r" 
		expect {
			timeout {
				p_err "timed out - context unknown..?!" 1
			}
			$_context_firmware_prompt {
				set ctx "firmware"
			}
			$_context_kernel_prompt {
				set ctx "kernel"
			}
			"login:" {
				send -s "root\r"
				expect {
					$_context_kernel_prompt {
						set ctx "kernel"
					}
					timeout {
						p_err "timed out - context\
						unknown..?!" 1"
					}	
				}
			}
		}
	}
	return $ctx
}
