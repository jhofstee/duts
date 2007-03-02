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
	## check rootpath 
	##
	global CFG_ROOTPATH
	if ![info exists CFG_ROOTPATH] {
		p_err "variable CFG_ROOTPATH is not set, please update the\
		       .tgt definition file for your board" 1
	} else {
		p_verb "CFG_ROOTPATH '$CFG_ROOTPATH'"
		if ![valid_dir $CFG_ROOTPATH] {
			p_err "problem validating rootpath: '$CFG_ROOTPATH'" 1
		}
	}

	##
	## check if the kernel file is ok
	##
	if ![valid_kernel_file $_context_kernel_image] {
		p_err "problems validating kernel file" 1
	}

	if ![_context_firmware_get_prompt] {
		p_err "could not get firmware prompt" 1
	}

	##
	## set bootfile
	##
	_context_firmware_command "setenv bootfile $_context_kernel_image" ".*"

	##
	## set rootpath
	##
	_context_firmware_command "setenv rootpath $CFG_ROOTPATH" ".*"

	##
	## run net_nfs
	##
#	_context_firmware_command "run net_nfs" "ENET"

	set timeout 120
	send -s "run net_nfs\r"

	expect {
		timeout {
			p_err "timed out after 'bootcmd'"
			return 0
		}
		"Bad Magic Number" {
			p_err "problems finding image?!"
			return 0
		}
		"Linux version" {
			set cur_context "kernel"
			set timeout 300

			expect {
				timeout {
					p_err "timed out while waiting for\
					       login prompt" 1
				}
				-re ".*Kernel\\ panic" {
					##
					## This is really bad - we cannot be
					## sure if the crash does not confuse
					## test cases that were scheduled for
					## execution after this one.
					##
					p_err "PANIC!"
					if [ask_yesno "continue execution? "] {
						return 
					} else {
						exit1
					}
				}
				"login: " {
					p_verb "login prompt OK"
				}
			}

			set timeout $TIMEOUT 
			send -s "root\r"
			expect {
				timeout {
					p_err "timed out while waiting for\
					       kernel prompt" 1
			}
				-re ".*$_context_kernel_prompt" {
				}
			}
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
