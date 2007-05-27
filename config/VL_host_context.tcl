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

#
# this method implements sending command and receiving response in the 'host'
# context
#

proc _context_host_command {cmd rsp {slp 0.25}} {

#exp_internal 1

	global _context_host_prompt
	global _context_host_shell
	set shell $_context_host_shell
	set prompt $_context_host_prompt

	if [regexp {^\!.*} $cmd] {
		run_external_script $cmd
		return
	}

	expect "*"
	if [catch {spawn $shell}] {
		p_err "couldn't spawn '$shell' command" 1
	}

	expect {
		$prompt { p_verb "shell prompt OK" }
		timeout { p_err "couldn't get '$prompt' shell prompt" 1 }
	}

	p_verb "executing host command: '$cmd'"
	send -s $cmd\r

	p_verb "expecting host response: '$rsp'"
	# escape [, $, space in prompt string so we can use it in regexp
	# comparison
	set p [string map {"]" "\\]" "$" "\\$" " " "\\ "} $prompt]
	expect {
		-re ($rsp)$p {
			p_verb "response OK"
		}
		timeout { p_err "couldn't get '$rsp' response" 1 }
	}
}
