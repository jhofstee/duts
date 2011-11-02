#
# (C) Copyright 2011 Detlev Zundel <dzu@denx.de>, DENX Software Engineering
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

#
# method implementing connecting to the host, returns spawn_id of the
# created process
#
proc _device_connect_host {} {
	global host_connected host_con
	global _context_host_prompt _context_host_shell

	set shell $_context_host_shell
	set p $_context_host_prompt

	if {$host_connected == "yes"} {
		return $host_con
	}

	# escape [, $, space in prompt string so we can use it in regexp
	# comparison
	set p [string map {"]" "\\]" "$" "\\$" " " "\\ "} $p]

	if [catch {spawn $shell}] {
		p_err "couldn't spawn '$shell' command" 1
	}

	expect {
		"$ " { p_verb "initial shell prompt OK" }
		timeout { p_err "couldn't get initial shell prompt" 1 }
	}

	set host_con $spawn_id
	set host_connected "yes"

	# Reset host prompt to something sane so we know what to
	# expect. PROMPT_COMMAND is a bash specific pre-prompt command
	# used on many distributions - unset it so it doesn't inerfere
	# with the log
	send "PS1='\[\\u@\\h\]$ ' ; export PS1 ; unset PROMPT_COMMAND\r"
	expect {
		-re "PROMPT_COMMAND.*$p" { p_verb "shell prompt OK" }
		timeout { p_err "couldn't get '$p' shell prompt" 1 }
	}

	return $host_con;
}

proc _device_disconnect_host {} {
	global host_connected host_con

	p_verb "Closing host connection"
	if {$host_connected == "yes"} {
		close -i $host_con
		set host_connected "no"
	}
}

proc _context_host_get_prompt {} {

	global _context_host_prompt

	set p $_context_host_prompt
	set timeout 3
	set rv 1

	# escape [, $, space in prompt string so we can use it in regexp
	# comparison
	set p [string map {"]" "\\]" "$" "\\$" " " "\\ "} $p]

	expect "*"
	send -s "\r"
	expect {
		timeout {
			set rv 0
			p_verb "timed out while waiting on host prompt: \
			'$p'"
		}
		-re ".*$p" {
			p_verb "host prompt OK"
		}
	}

	return $rv
}


#
# this method implements sending command and receiving response in the 'host'
# context
#

proc _context_host_command {cmd rsp {slp 0.25}} {

	global _context_host_prompt dry_run

	set rv 1
	set p $_context_host_prompt

	# escape [, $, space in prompt string so we can use it in regexp
	# comparison
	set p [string map {"]" "\\]" "$" "\\$" " " "\\ "} $p]

	p_verb "CMD '$cmd', RSP '$rsp', P '$p'"

	send -s "$cmd\r"

#	sleep $slp
	expect {
		-re "($rsp)(.*)$p" {
			p_verb "host command executed OK"
		}
		timeout {
			set rv 0

			p_err "timed out while waiting on cmd '$cmd'... weird"

			if ![ask_yesno "do you want to continue? "] {
				exit1
			}
		}
	}

	return $rv
}

proc _host_current_context {} {
	global host_connected

	if {$host_connected == "yes"} {
		return "host";
	} else {
		return "off"
	}
}
