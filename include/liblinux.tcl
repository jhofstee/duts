#
# (C) Copyright 2008-2010 Detlev Zundel <dzu@denx.de>, DENX Software Engineering
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

proc boot_kernel_nfs {cmd} {
	global console_con BOARD CFG_ROOTPATH
	global CFG_LINUX_KERNEL CFG_FDT_START CFG_FDT_FILE

	set spawn_id $console_con
	expect "*"

	if ![var_exists CFG_ROOTPATH] {
		p_err "variable CFG_ROOTPATH is not set, please update the\
		       .tgt definition file for your board" 1
	}

	if {$cmd == "net_nfs"} {
		# Do we need a FDT?  This is triggered by the CFG_FDT_START
		# variable which has _no_ global default.
		if [var_exists CFG_FDT_START] {
			_context_firmware_command "setenv fdt_file [subst $CFG_FDT_FILE]" ".*"
		}
		_context_firmware_command "setenv bootfile [subst $CFG_LINUX_KERNEL]" ""
	}
	_context_firmware_command "setenv rootpath [subst $CFG_ROOTPATH]" ""

	# Run provided command (net_nfs or flash_nfs)
	set timeout 120
	_context_firmware_command "printenv $cmd" ""
	send -s "run $cmd\r"

	expect {
		timeout {
			p_err "timed out waiting for login prompt"
		}
		"login:" {
			set cur_context "kernel"
			return [login_kernel "root" "root"]
		}
	}
}
