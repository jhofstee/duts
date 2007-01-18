#
#
#
#

proc valid_kernel_file {f} {
	global control_con
	
	set rv 0
	set cmd "file"

	if [catch {spawn -noecho $cmd $f}] {
		p_err "couldn't spawn '$cmd' command" 1
	}	

	expect {
		timeout {
			 p_err "timed out while validating kernel file"
		}
		"PPCBoot image" {
#			p_verb "file OK"
			set rv 1
		}
	}

	return $rv
}

#
# this method is the kernel context handler - it is executed upon entering
# this context. assume we start from 'firmware' context
#
proc _context_kernel_handler {} {
	global _context_kernel_prompt _context_kernel_image TIMEOUT

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

	set timeout $TIMEOUT 
	send -s "root\r"
	expect {
		$p { }
		timeout {
			p_err "timed out while logging on root" 1
		}
	}
}

proc _context_kernel_get_prompt {} {

	global _context_kernel_prompt

	set p $_context_kernel_prompt
	set timeout 3
	set rv 1

	send -s " \r"
	expect {
		timeout {
			set rv 0
			p_verb "timed out while waiting on kernel prompt: \
			'$p'"
		}
		-r ".*$p" {
			p_verb "kernel prompt OK"
		}
	}

	return $rv
}
#
# this method implements sending command and receiving response
#
proc _context_kernel_command {cmd rsp {slp 0.25}} {
	global _context_kernel_prompt

	set p $_context_kernel_prompt
	set rv 1

	p_verb "CMD $cmd, RSP '$rsp', prompt $p"

	#expect "*"
	if ![_context_kernel_get_prompt] {
		p_err "could not get kernel prompt"
		return 0
	}

	send -s "$cmd\r"

	sleep $slp
	expect {
		-re "($rsp)(.*)$p" {
			p_verb "kernel command executed OK"
		}
		timeout {
			set rv 0

			p_err "timed out while waiting on cmd '$cmd'"
			if ![ask_yesno "do you want to continue? "] {
				exit1
			}
		}
	}

	return $rv
}
