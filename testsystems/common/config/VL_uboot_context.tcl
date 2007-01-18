#
# this method is the firmware context handler - it is executed upon entering
# this context (i.e. changing from some other context)
#
proc _context_firmware_handler {} {

	global cur_context _context_firmware_prompt _context_kernel_prompt
	global TIMEOUT

#p_banner "U-Boot context handler" 

#	expect "*"

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

#exp_internal 1

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

	set timeout 20
	#
	# get "Hit any key to stop autoboot"
	# key press 
	# get prompt
	#
	expect {
		timeout {
			p_err "timed out while waiting for autoboot prompt" 1
		}
		-re ".*any key to stop.*" {
			send -s "\r"
		}
	}
	
	set timeout $TIMEOUT
	expect {
		timeout {
			p_err "timed out while waiting for U-Boot prompt" 1
		}
		-re (.*)$_context_firmware_prompt { }
		-re (.*)$_context_kernel_prompt { }
	}
}

proc _context_firmware_get_prompt {} {

	global _context_firmware_prompt

	set p $_context_firmware_prompt
	set timeout 3
	set rv 1

	send -s " \r"
	expect {
		timeout {
			set rv 0
			p_verb "timed out while waiting on firmware prompt: \
			'$p'"
		}
		-r ".*$p" {
			p_verb "firmware prompt OK"
		}
	}

	return $rv
}

#
# this method implements sending command and receiving response
#
proc _context_firmware_command {cmd rsp {slp 0.35}} {

	global _context_firmware_prompt dry_run

	set rv 1
	set p $_context_firmware_prompt

	p_verb "CMD '$cmd', RSP '$rsp'"

	if ![_context_firmware_get_prompt] {
		p_err "could not get firmware prompt"
		return 0
	}

	send -s "$cmd\r"

	sleep $slp
	expect {
		-re "Unknown\\ command.*$p" {
			p_verb "Hmm, no command compiled in.."
			set rv 0
		}
		-re "($rsp)(.*)$p" {
			p_verb "firmware command executed OK"
		}
		timeout {
			set rv 0

			p_err "timed out while waiting on cmd '$cmd'... Sure\
			the board is alive?"

		#TODO this should be lower i.e. where the cmd_uboot is 
		#called, but we need to return result value first
			if ![ask_yesno "do you want to continue? "] {
				exit1
			}
		}
	}

	return $rv
}
