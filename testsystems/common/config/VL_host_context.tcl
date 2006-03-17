#
# this method implements sending command and receiving response in the 'host'
# context
#

proc _context_host_command {cmd rsp {slp 0.25}} {

#exp_internal 1

	global _context_host_prompt remote
	global _context_host_shell
	set shell $_context_host_shell
	set prompt $_context_host_prompt

	if [regexp {^\!.*} $cmd] {
		run_external_script $cmd
		return
	}

	expect "*"
	if {$remote == "yes"} {
		#TODO
	} else {
		# we're local on VL host so need to spawn the bash process
		if [catch {spawn $shell}] {
			p_err "couldn't spawn '$shell' command" 1
		}
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
