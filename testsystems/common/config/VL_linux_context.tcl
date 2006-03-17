#
#
#
#

proc valid_kernel_file {f} {
	global control_con remote
	
	set rv 1
	set cmd "file"

#p_verb "VALID $cmd"

	if {$remote == "yes"} {
		if {$control_con == ""} {
			p_err "no spawn_id of the control connection" 1
		}
		set spawn_id $control_con
		send -s "$cmd $f\r"
	} else {
		# we're local on VL host so need to spawn the power_on process
		if [catch {spawn -noecho $cmd $f}] {
			p_err "couldn't spawn '$cmd' command" 1
		}	
	}

	expect {
		timeout {
			 p_err "timed out while validating kernel file"
			 set rv 0
		}
		"PPCBoot image" {
#			p_verb "file OK"
		}
	}

	return $rv
}

#
# this method is the kernel context handler - it is executed upon entering
# this context. assume we start from 'firmware' context
#
proc _context_kernel_handler {} {
	global _context_kernel_prompt _context_kernel_image

	set p $_context_kernel_prompt

#p_banner "Linux context handler"

	expect "*"

	##
	## check if the kernel file is ok
	##
	if ![valid_kernel_file $_context_kernel_image] {
		p_err "problems validating kernel file" 1
	}

	##
	## set bootfile
	##
	_context_firmware_command "setenv bootfile $_context_kernel_image" ".*"

	##
	## run net_nfs
	##
#	_context_firmware_command "run net_nfs" "ENET"

	set timeout 120
	send -s "run net_nfs\r"
	expect {
		timeout {
			p_err "timed out after 'run net_nfs'" 1
		}
		"Uncompressing Kernel Image" {
		}
	}

	set timeout 300
	expect "login: "

	set timeout 10
	send -s "root\r"
	expect {
		$p { }
		timeout {
			p_err "timed out while logging on root" 1
		}
	}
}

#
# this method implements sending command and receiving response
#
proc _context_kernel_command {cmd rsp {slp 0.25}} {
	global _context_kernel_prompt

	set p $_context_kernel_prompt

#p_verb "CMD $cmd, RSP '$rsp', prompt $p"

	expect "*"
	send -s "$cmd\r"

	sleep $slp
	expect {
		-re "($rsp)(.*)$p" {
		}
		timeout {
			p_err "timed out after Linux command '$cmd'" 1
		}
	}
}
