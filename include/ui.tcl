#
# (C) Copyright 2006, 2007
# Wolfgang Denk, DENX Software Engineering, wd@denx.de
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
##
## user interface routines
##
###############################################################################

#
# DUTS usage
#
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
	puts "    -d <dir>  (alternative working directory)"
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
	{ cmd_dt "dt" "display details for a test case" }
	{ cmd_b "b" "display details for a target board" }
	{ cmd_t "t" "run test case(s)" }
	{ cmd_c "c" "display details for configuration view"}
}


#
# command 'lt'
#
proc cmd_lt {a} {

	global board_name l_testcases

	set bn [lindex $a 0]

	if {$bn != ""} {
		set board_name $bn

		##
		## load config descriptions
		##
		load_all_devices
		
		##
		## load board-specific TCs
		##
		if ![valid_board_name] {
			exit1
		}
		load_custom_tcs
	} else {

		##
		## load common (without board-specific) TCs files
		##
		load_tcs
	}

	if {[llength $l_testcases] > 0} {
		puts "List of testcases currently defined:"
		puts " "
	} else {
		puts "No testcases defined...?!"
		return
	}

	show_tc_list
}


proc cmd_dt_usage {} {
	
	global argv0
	
	puts "usage: "
	puts "$argv0 \[options\] dt <TC name> \[<board name>\]"
	puts " "
	puts "  If <board name> is present test case <TC name> is searched in\
	        the board's custom TC list and details are shown when found."
	puts ""
	puts "  If <board name> is empty <TC name> is searched in the common\
	        test cases list and details shown."
	puts " "
	exit 1
}

#
# command 'dt' - test case description
#
proc cmd_dt {a} {

	global l_boards board_name
	
	if {[llength $a] < 1} {
		p_err "no TC name given..?! Use 'lt' command for a list of\
		available test cases."
		cmd_dt_usage
	}

	##
	## get TC and board name
	##
	set tc [lindex $a 0]
	set bn [lindex $a 1]

	if {$bn != ""} {
		set board_name $bn

		##
		## load config descriptions
		##
		load_all_devices
		
		##
		## load board-specific TCs
		##
		if ![valid_board_name] {
			exit1
		}
		load_custom_tcs

	} else {
		##
		## load common TCs
		##
		load_tcs
	}

	show_tc_details $tc
}

proc cmd_t_usage {} {
	
	global argv0
	
	puts "usage: "
	puts "$argv0 \[options\] t <board name> \[params\]"
	puts "  where params are:"
	puts " "
	puts "  \[-c config\]"
	puts ""
	puts "  <TCfile1> <TCfile2> ... <TCfileX>"
	puts "      runs test cases from <TCfile1..X> files"
	puts " "
	puts "  -t <TC1> <TC2> ... <TCx>"
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

	global board_name l_runlist BASE_DIR l_testcases selected_config
	global CONFIG_DEFAULT_NAME

	if {[llength $a] < 1} {
		p_err "no board name given..?! Use 'b' command for list of\
		supported boards"
		cmd_t_usage
	}

	##
	## get board name
	##
	set bn [lindex $a 0] 
	set a [lrange $a 1 end]
	set board_name $bn

	##
	## load devices descriptions
	##
	load_all_devices

	if ![valid_board_name] {
		exit1
#		p_err "Invalid board name: $bn" 1
	}
	puts "Board name: $bn"

	##
	## parse remaining params
	##
	set max [llength $a]
	if {$max > 0} {
		# we have params for 't' command so need to take selective
		# actions
		cmd_t_parse_params $a

		# check if the required TCs are defined
		check_tc_list l_runlist

	} else {
		# no params after 'board_name' so let's run all defined test
		# cases using default config

		# load TC descriptions
		load_tcs
		load_custom_tcs

		set l_runlist $l_testcases
		p_verb "ALL defined test cases selected to run"
	}
	
	##
	## load configuration views' definitions
	##
	if {$selected_config == ""} {
		set selected_config $CONFIG_DEFAULT_NAME
	}
	load_configs
	puts "Selected config: $selected_config"

	##
	## run selected TCs
	## 
	puts "List of selected test cases:\n$l_runlist\n"
	if [ask_yesno "confirm to start execution? "] {
		run_tc_list l_runlist
	}
}


#
# process parameters for 't' command, sets l_runlist with a list of test cases
# to execute
#
proc cmd_t_parse_params {a} {

	global l_runlist l_testcases selected_config CONFIG_DEFAULT_NAME

	# by default the params list gives file names with test groups
	set list_type "files"

	set selected_config ""

	set max [llength $a]
	for {set i 0} {$i < $max} {incr i} {
		set arg [lindex $a $i]

		switch -- $arg "-t" {
			# we have the list of individual TCs rather than 
			# file names of test groups...
			set list_type "tcs"
			p_verb "individual TCs being selected"
			continue
		} "-c" {
			# user-supplied configuration view
			incr i
			set selected_config [lindex $a $i]
			
			p_verb "selected configuration: $selected_config"
			continue
		}

		#
		# remaining parameters are the list of files/test cases
		#
		if {$list_type == "tcs"} {
			# add element (TC name to a run list)
			p_verb "adding $arg to runlist"
			lappend l_runlist $arg

		} else {
			# element is a TC file name
			p_verb "loading TC file $arg"

			# load the file with TC description(s)
			load_tc_file $arg

			# schedule all TCs loaded from file(s) to run
			set l_runlist $l_testcases
		}
	}

	# if we didn't load a specific TC file, lets load all definitions
	if {$list_type == "tcs"} {
		load_tcs
		load_custom_tcs
	}

	if {[llength $l_runlist] == 0} {
		if {$selected_config != ""} {
			# seems no TC's specified after -c config - let's take
			# all we have
			set l_runlist $l_testcases
			p_verb "ALL defined test cases selected to run"

		} else {
			p_err "No test cases selected..?!"
			cmd_t_usage
		}
	}

#	if {$files_ok != "yes"} {
#		p_err "Invalid test case file(s)...?!" 1
#	}
}


#
# command 'b'
#
proc cmd_b {a} {

	global board_name
	set bn [lindex $a 0]

	# NOTICE: due to current implementation of Vars section parsing
	# routine the $board_name global *must* be set before
	# load_all_devices{} is called, but the valid_board_name{} *must
	# NOT* be called before load_all_devices{} as it relies on
	# load_all_devices{} effects... so we defer board's name validation a
	# bit later
	set board_name $bn

	# read in config definition files
	load_all_devices
	
	if {$bn == ""} {
		##
		## list all config definitions
		##
		list_all_devices

	} else {
		##
		## show config details for the board name
		##
		if ![valid_board_name] {
			exit1
		}
		show_device
	}
}


#
# command 'c'
#
proc cmd_c {a} {
	global cur_config selected_config CONFIG_DEFAULT_NAME l_configs
	global a_configs _context_kernel _context_firmware

	##
	## config name
	##
	set cn [lindex $a 0]
	if {$cn == ""} {
		set selected_config $CONFIG_DEFAULT_NAME
	} else {
		set selected_config $cn
	}
	load_configs

	if {$cn == ""} {
		puts "Defined configuration views:"
		foreach c $l_configs {
			puts "  $c"
		}
		puts ""
	} else {
		if ![on_list l_configs $cn] {
			p_err "Config view '$cn' not defined?!" 1
		}
		puts "Details for configuration view '$cn'"
		if [in_array a_configs "$cn,$_context_kernel"] {
			puts "Kernel context '$_context_kernel'"
			puts $a_configs($cn,$_context_kernel)
		}
		if [in_array a_configs "$cn,$_context_firmware"] {
			puts "Firmware context '$_context_firmware'"
			puts $a_configs($cn,$_context_firmware)
		}
		if [in_array a_configs "$cn,host"] {
			puts "Host context 'host'"
			puts $a_configs($cn,host)
		}
	}
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
# validates DUTS command and (optional) parameters
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

	global argc argv working_dir board_name

	for {set i 0} {$i < $argc} {incr i} {
		set arg [lindex $argv $i]

		##
		## get options
		##
		switch -- $arg "-d" {
			incr i
			set working_dir [lindex $argv $i]
			
			if ![valid_dir $working_dir] {
				p_err "Incorrect value for option -d" 1
			}
			
			p_verb "alternative descriptions dir set: $working_dir"
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
		p_err "Incorrect command: $cmd" 1
	}
	
	##
	## run command with its (optional) params - this passes control to the
	## main handler of a DUTS command that checks its arguments etc.
	## and does what is supposed to..
	##
	cmd_run $cmd $arg
}
