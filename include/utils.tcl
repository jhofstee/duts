#
# (C) Copyright 2006-2008 DENX Software Engineering
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

###############################################################################
# misc
###############################################################################

#
# validates board name: checks if name found on the list of all boards
#
# bn: board name, if empty take global $board_name
#
proc valid_board_name {{bn ""}} {

	global board_name l_boards

	if {$bn == ""} {
		set bn $board_name
	}
	if {[lsearch $l_boards $bn] < 0} {
		return 0
	} else {
		return 1
	}
}


#
# runs external [expect] script
#
# fn: filename with respect to the DUTS working/testcases dir
#
proc run_external_script {fn} {
	global working_dir dry_run TC_DESCR_DIR

	set f [string trimleft $fn "!"]
	set f "$working_dir/$TC_DESCR_DIR/$f"
	set rv 1

	if ![valid_file $f] {
		p_err "problems with accessing file: $f"
		return 0
	}

	p_verb "running external script $f"
	if  {$dry_run == "yes"} {
		p_warn "dry run activated, skipping execution of '$f'"
	} else {
		set err ""
		set ret 0
		if [catch {set ret [source $f]} err] {
			p_err "problems with source'ing '$f'?!"
			puts "  $err"
			set rv 0
		}
		set rv $ret
	}

	return $rv
}


#
# Performs a UNIX login with user/pass pair. It is assumed the caller has already
# detected the "login: " prompt
#
# returns 0/1
#
proc login_kernel {user {pass ""} {spid ""}} {
	global _context_kernel_prompt TIMEOUT console_con

	if {$spid eq ""} {
		set spawn_id $console_con
	} else {
		set spawn_id $spid
	}
	set timeout $TIMEOUT
	send -s "$user\r"
	expect {
		"assword: " {
			send -s "$pass\r"
			expect {
				-re ".*$_context_kernel_prompt" {
					return 1
				}
				"incorrect" {
					p_err "wrong login or password"
					return 0
				}
				timeout {
					p_err "timed out while waiting for kernel prompt"
					return 0
				}
			}
		}
		-re ".*$_context_kernel_prompt" {
			return 1
		}
		timeout {
			p_err "timed out while waiting for kernel prompt"
			return 0
		}
	}
}


proc boot_kernel_net_nfs {} {

	global _context_kernel_image TIMEOUT console_con
	global CFG_FDT_FILE CFG_ROOTPATH

	set spawn_id $console_con
	expect "*"

	##
	## check rootpath
	##
	if ![var_exists CFG_ROOTPATH] {
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
	## set fdt_file - only for arch/powerpc kernels
	## note that we can still continue without fdt_file if
	## we test a bootwrapped kernel.
	##

	if {[get_device_attr "makearch"] == "powerpc"} {
		if ![var_exists CFG_FDT_FILE] {
			if [var_exists CFG_FDT_START] {
				p_err "Defined fdt start, but not CFG_FDT_NAME, config inconsistent..." 1
			}
			p_warn " variable CFG_FDT_FILE is not set."
			p_warn " assuming bootwrapper-crafted cuImage."
		} else {
			_context_firmware_command "setenv fdt_file $CFG_FDT_FILE" ".*"
		}
	}

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
		"TFTP error" {
			p_err "TFTP problems"
			# send CTRL-C
			send -s "\003"
			if ![_context_firmware_get_prompt] {
				p_err "could not recover after CTRL-C, aborting..." 1
			}

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
						return 1
					} else {
						exit1
					}
				}
				"login:" {
					if ![login_kernel "root" "root"] {
						p_err "could not login" 1
					}
					return 1
				}
			}
		}
	}
}
