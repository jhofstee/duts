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
				"login:" {
					if ![login_kernel "root" "root"] {
						p_err "could not login" 1
					}
				}
			}
		}
	}
}

proc _context_kernel_get_prompt {} {

	global _context_kernel_prompt _context_kernel_alt_prompt

	# if there's an alt prompt set p2 with it
	set p $_context_kernel_prompt
	if [var_exists _context_kernel_alt_prompt] {
		set p2 $_context_kernel_alt_prompt
	} else {
		set p2 $p
	}

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
		-r ".*$p2" {
			p_verb "kernel prompt2 OK"
		}
	}

	return $rv
}
#
# this method implements sending command and receiving response
#
proc _context_kernel_command {cmd rsp {slp 0.25}} {
	global _context_kernel_prompt _context_kernel_alt_prompt

	set p $_context_kernel_prompt
	if [var_exists _context_kernel_alt_prompt] {
		set p2 $_context_kernel_alt_prompt
	} else {
		set p2 $p
	}

	set rv 1

	p_verb "CMD $cmd, RSP '$rsp', prompt $p/$p2"

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
		-re "($rsp)(.*)$p2" {
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
