#
#
#
#

#
# this method is the firmware context handler - it is executed upon entering
# this context
#
proc _context_firmware_handler {} {

	global cur_context _context_firmware_prompt _context_kernel_prompt

#p_banner "U-Boot context handler" 

	expect "*"
	#
	# the following cases are possible:
	# 1. device is off
	#	-invoke _device_power_on() method 
	#
	# 2. device is in firmware (u-boot) context
	#	-verify we're really powered on 
	#	-if so do nothing, otherwise invoke _device_power_on()
	#
	# 3. device is in kernel (linux) context
	#	-verify we have linux prompt
	#	-reboot
	#

	
	if [is_powered_on] {
		# we're powered on
		if {$cur_context == "kernel"} {
			#TODO get linux prompt
			set timeout 120
			send -s "reboot\r"
			expect {
				timeout {
					p_err "timed out while rebooting" 1
				}
				"Restarting system" {
					set timeout 10
				}
			}
		}
	} else {
		_device_power_on
	}


	#
	# get "Hit any key to stop autoboot"
	# key press 
	# get prompt
	#
	expect {
		timeout {
			p_err "timed out while waiting for autoboot prompt" 1
		}
		"Hit any key to stop" {
			send -s "\r"
		}
	}

	send -s " \r"
	expect {
		timeout {
			p_err "timed out while waiting for U-Boot prompt" 1
		}
		$_context_firmware_prompt { }
		$_context_kernel_prompt { }
	}
}

#
# this method implements sending command and receiving response
#
proc _context_firmware_command {cmd rsp {slp 0.35}} {

	global _context_firmware_prompt

	set p $_context_firmware_prompt
	set ok 1

#p_verb "CMD $cmd, RSP '$rsp'"

	# clear expect's internal buffer
	expect "*"

#	set c {$cmd}

	send -s "$cmd\r"
#	send -s "$c\r"

	sleep $slp
	expect {
		-re "($rsp)" {
			expect {
				$p { }
				timeout {
					p_err "timed out after U-boot command" 1
				}	
			}
		}
		timeout {
			p_err "timed out while waiting on cmd '$cmd'... Sure\
			the board is alive?"

		#TODO this should be lower i.e. where the cmd_uboot is 
		#called, but we need to return result value first
			ask_yesno "do you want to continue? "
		}
	}
}	
