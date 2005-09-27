

proc usage {} {
	global argv0
	global duts_cmds
	
	puts "usage: $argv0 \[options\] <command> \[params\]"
	puts "  <command> is:"
	puts "   " 
	foreach c $duts_cmds {
		puts [ format "    %s\t- %s" [lindex $c 1] [lindex $c 2]]
	}
	puts "   " 
	puts "  \[options\] are:"
	puts "   " 
	puts "    -d <dir>  (alternative dir)"
	puts "    -n        (do NOT execute real actions)"
	puts "    -v        (verbose)"
	puts " " 
	exit 1
}


#
# global structure describing DUTS tool commands
#
# { <proc name> "command name" "text description"
#
set duts_cmds {
	{ cmd_lt "lt" "list test cases"}
	{ cmd_c "c" "display config details for a target" }
	{ cmd_t "t" "run test case(s)" }
}


#
# command 'lt'
#
proc cmd_lt {a} {
	
	load_tcs

	# TODO load TC files for all boards
	#load_all_tcs

	global l_testcases

	if {[llength $l_testcases] > 0} {
		puts "List of testcases currently defined:"
		puts " "
	} else {
		puts "No testcases defined...?!"
		return
	}

	show_tc_list
}


proc cmd_t_usage {} {
	
	global argv0
	
	puts "usage: "
	puts "$argv0 \[options\] t <board name> \[params\]"
	puts "  where params are:"
	puts " "
	puts "  <TGfile1> <TGfile2> ... <TGfileX>"
	puts "      runs test cases listed in <TGfile1..X> files"
	puts " "
	puts "  -c <TC1> <TC2> ... <TCx>"
	puts "      runs test cases <TC1..X> selected by their names"
	puts " "
	puts "  (empty params)"
	puts "      runs all test cases defined (use 'lt' command for complete\
		list)"
	puts " "
	exit 1
}

#
# command 't'
#
proc cmd_t {a} {

	global board_name l_runlist

	if {[llength $a] < 1} {
		p_err "no board name given..?! Use 'c' command for list of\
		supported boards"
		cmd_t_usage
	}
	
	##
	## get board name
	##
	set bn [lindex $a 0] 
	set a [lrange $a 1 end]
	set max [llength $a]

	if ![valid_board_name $bn] {
		exit1 "Invalid board name: $bn"
	}
	set board_name $bn
	puts "Board name: $bn"

	##
	## load TC descriptions
	##
	load_tcs
	load_custom_tcs

	##
	## get list of TC to run from the remaining params
	## 
	if {$max > 0} {
		# we have params for 't' command so need to take selective
		# actions
		cmd_t_parse_params $a

		# check if the required TCs are defined
		check_tc_list l_runlist

		if { [llength $l_runlist] == 0 } {
			p_err "No test cases selected..?!"
			cmd_t_usage
		}

	} else {
		# no params after 't' so let's run all defined test cases
		global l_testcases
		set l_runlist $l_testcases

		p_verb "ALL defined test cases selected to run"

#		send_user "confirm? \[y] "
#		expect_user -re "(.*)\n" { set ans $expect_out(1,string) }
#		if {$ans != "y" && $ans != ""} {
#			exit
#		}

	}

	##
	## run selected TCs
	## 
	puts "List of selected test cases:\n$l_runlist\n"
	set timeout -1
	send_user "confirm to start execution? \[y] "
	expect_user -re "(.*)\n" { set ans $expect_out(1,string) }
	if {$ans != "y" && $ans != ""} {
		exit
	}
	set timeout 10

	run_tc_list l_runlist
}


#
# process parameters for 't' command, sets l_runlist with a list of test cases
# to execute
#
proc cmd_t_parse_params {a} {

	global l_runlist

	set max [llength $a]
	# by default the params list gives file names with test groups
	set list_type "files"
	set files_ok "yes"

	for {set i 0} {$i < $max} {incr i} {
		set arg [lindex $a $i]

		switch -- $arg "-c" {
			
			# we have the list of individual TCs rather than 
			# file names of test groups...
			set list_type "tcs"
			p_verb "individual TCs being selected"
			continue
		}	

		# remaining parameters are the list of files/test cases
		
		if {$list_type == "tcs"} {
			# add element (TC name to a run list)
			p_verb "adding $arg to runlist"
			lappend l_runlist $arg
			
		} else {
			# element is a TG file name

			if ![valid_file $arg] {
#				p_err "problems with accessing file: $arg"
				set files_ok "no"
				continue
			}
			p_verb "loading TG file $arg"
			source $arg
			set l_runlist [tg_list]
		}
	}

	if {$files_ok != "yes"} {
		exit1 "Invalid test group file(s)...?!"
	}
}


proc p_verb {msg} {
	global verbose

	if {$verbose == "yes"} {
		puts "DUTS: $msg"
	}
}


proc p_err {msg} {
	puts "ERROR: $msg"
}


proc p_banner {msg {p "* "}} {

	set len [expr 5 + [string length $msg]]
	set i 0
	set p_len [string length $p]
	
	while {$i + $p_len <= $len} {
		puts -nonewline $p
		incr i $p_len
	}
	puts -nonewline "\n"
	puts "$p $msg"
	set i 0
	while {$i + $p_len <= $len} {
		puts -nonewline $p
		incr i $p_len
	}
	puts -nonewline "\n"
}



#
# runs handler of a given command; it's assumed the handler exists i.e. a 
# procedure is defined, so the calling context needs to verify this
#
# c: command
# p: params/arguments
#
proc cmd_run {c p} {
	global duts_cmds
	
	foreach dc $duts_cmds {
		if { [lindex $dc 1] == $c } {
			set prc [lindex $dc 0]
			p_verb "calling procedure: $prc"
			$prc $p
		}
	}
}

#
# validate board name
#
# bn: board name
#
proc valid_board_name {bn} {

	#TODO
	p_verb "found board $bn, OK"
	return 1
}

#
# validate DUTS command and (optional) parameters
#
# c: command
#
proc valid_cmd {c} {

	global duts_cmds
	set rv 0
	set f 0

	foreach dc $duts_cmds {
		if { [lindex $dc 1] == $c } {
			set f 1
			set prc [lindex $dc 0]
			p_verb "found command: $c, proc: $prc"

			# check if we have a proc for this cmd
			if { [llength [info procs $prc]] } {
				p_verb "procedure $prc defined, OK"
				set rv 1
			} else {
				p_err "command $c does NOT have a handler..?!"
			}
			
			break
		}
	}
	if {!$f} {
		p_err "command $c NOT recognized..?!"
	}

	return $rv
}


#
# parses command line parameters supplied by the user
#
proc parse_params {} {

	global argc argv tc_dir board_name

	for {set i 0} {$i < $argc} {incr i} {
		set arg [lindex $argv $i]

		##
		## get options
		##
		switch -- $arg "-d" {
			incr i
			set tc_dir [lindex $argv $i]
			
			if ![valid_dir $tc_dir] {
				exit1 "Incorrect value for option -d"
			}
			
			p_verb "alternative descriptions dir set: $tc_dir"
			continue

		} "-n" {
			global dry_run
			set dry_run "yes"
			p_banner "NO-OP mode selected, no actual\
				actions will be peformed on the target!" "*"

			continue

		} "-v" {
			global verbose
			set verbose "yes"
			p_verb "verbose mode ON"
			continue
		}

		##
		## get command
		##
		set cmd $arg
		# pass remaining params after command
		incr i
		set arg [lrange $argv $i end]
		break	
	}

	if ![info exists cmd] {
		p_err "missing command..?!"
		usage
	}
	
	p_verb "command: $cmd"
	p_verb "remaining params: $arg"
	
	##
	## validate command
	##
	if ![valid_cmd $cmd] {
		exit1 "Incorrect command: $cmd"
	}
	
	##
	## run command with its (optional) params - this passes control to the
	## main handler of a DUTS command that checks its arguments etc.
	## and does what is supposed to..
	##
	cmd_run $cmd $arg
}

