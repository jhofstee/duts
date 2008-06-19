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

proc valid_kernel_file {f} {
	if [catch {set output [exec file $f 2>@1]}] {
		p_err "cannot execute 'file' command"
		return 0
	}
	return [regexp "PPCBoot image" $output]
}

#
# this method is the kernel context handler - it is executed upon entering
# this context. assume we start from 'firmware' context
#
proc _context_kernel_handler {} {
	return [boot_kernel_net_nfs]
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
proc _context_kernel_command {cmd {rsp ".*"} {slp 0.25}} {
	global _context_kernel_prompt _context_kernel_alt_prompt

	set p $_context_kernel_prompt
	if [var_exists _context_kernel_alt_prompt] {
		set p2 $_context_kernel_alt_prompt
	} else {
		set p2 $p
	}

	set rv 1

	p_verb "CMD $cmd, RSP '$rsp', prompt $p/$p2"

	send -s "$cmd\r"

#	sleep $slp
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
