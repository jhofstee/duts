###############################################################################
# logging test case's flow to file
###############################################################################

#
# produces and returns log filename for a TC
#
proc logname {tc {ext "log"}} {

	global logs_location
	global board_name

	# a TC has individual log file
	if {[in_array a_testcases "$tc,logfile"]} {
		# TODO check if this is not empty string etc.
		# use arbitrary log filename if specified for a TC
		set lf $board_name$a_testcases($tc,logfile)
	} else {
		# default is derived from test cases's name 
		set lf $board_name$tc.$ext
	}
	set logs [file dirname $logs_location]
	# TODO - check if dir exists, we have access etc.

	return "$logs/$lf"
}


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
	set rv 0

	if {$bn == ""} {
		set bn $board_name
	}
	if {[lsearch $l_boards $bn] < 0} {
		p_err "board $board_name NOT known?! Use 'b' command for list\
		       of supported devices"
	} else {
		p_verb "board $board_name found, OK"
		set rv 1
	}
	return $rv
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
