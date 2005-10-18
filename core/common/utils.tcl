###############################################################################
#
# test cases (TC) processing 
#
# the following globals are required to exist (must be created by the "calling"
# context)
#
# l_testcases 
# a_testcases 
# cur_tc
#
###############################################################################

proc duts_tc {name args} {
	global cur_tc
	set cur_tc $name

	global l_testcases
	lappend l_testcases $name
	
#	puts "$name\n"
	uplevel 1 [lindex $args end]
}


proc Type {type} {
	global cur_tc
	global a_testcases

	set a_testcases($cur_tc,type) $type
}

proc Commands {commands} {
	
	global cur_tc
	global a_testcases

	set a_testcases($cur_tc,commands) $commands
}

proc Pre {commands} {

	global cur_tc
	global a_testcases
	set a_testcases($cur_tc,pre) $commands
		
}

proc Post {commands} {

	global cur_tc
	global a_testcases
	set a_testcases($cur_tc,post) $commands
}

proc Result {result} {
	global cur_tc
	global a_testcases

	set a_testcases($cur_tc,result) $result
}

proc Info {info} {
	global cur_tc
	global a_testcases

	set a_testcases($cur_tc,info) $info
}

proc Logfile {logfile} {
	global cur_tc
	global a_testcases

	set a_testcases($cur_tc,logfile) $logfile
}

proc Timeout {to} {
	global cur_tc
	global a_testcases

	set a_testcases($cur_tc,timeout) $to
}


#
# show list of all test cases
#
proc show_tc_list {} {

	global l_testcases
	global a_testcases

	foreach tc $l_testcases {

		puts "  $tc, $a_testcases($tc,type)"

#		puts "  $a_testcases($tc,commands)\n"
#		set max [expr [llength $a_testcases($tc,commands)]-1]
#		for {set i 0} {$i < $max} {incr i 2} {
#			set cmd [lindex $a_testcases($tc,commands) $i]
#			set rsp [lindex $a_testcases($tc,commands) [expr $i+1]]
#			puts [format "  CMD: %s, RSP: %s" $cmd $rsp] 
#		}
		
#		foreach c $a_testcases($tc,commands) {
#			puts "  $c"
#		}

		if { [ array get a_testcases $tc,info ] > 0 } {
#			puts "  $a_testcases($tc,info)"
		} else {
#			puts "  No description for a test case"
		}
	}

	puts -nonewline "\n"
}


proc run_external_tc {fn} {

	set f [string trimleft $fn "!"]

	if ![valid_file $f] {
		p_err "problems with accessing file: $f"
		return
	}
	p_verb "running external script $f"
	source $f
}


#
# runs a sequence of commands for a TC
#
proc run_cmds {cmds {t "u-boot"}} {

	global dry_run
	upvar $cmds c

#puts "RUN: $cmds"
#puts "CMDS:\n$c"

	# number of elements 
	set max [expr [llength $c]-1]

	if {$max == 0} {
		set c [lindex $c 0]
		# there's only one argument - check if we have an external
		# script to execute
		if [ regexp {^\!.*} $c] {
			if {$dry_run != "yes"} {
				run_external_tc $c
				# we allow only one special (external) TC
			}
			return

		} else {
			puts "WARNING: command $c seems broken, skipping..."
			return
		}
	}
	
	for {set i 0} {$i < $max} {incr i 2} {

		# command
		set cmd [lindex $c $i]

		# expected response
		set rsp [lindex $c [expr $i+1]]
		
		if [ regexp {^#.*} $cmd] {
			# commented line starts with a hash
			incr i
#			puts "skipping..."
			continue
		}

#		puts [format "  CMD: %s, RSP: %s" $cmd $rsp]


		if {$dry_run == "yes"} {
			# no op
			continue	
		}

		if { [string length $cmd] == 0} {
			puts "WARNING: empty command..."
			continue	
		}


		if {$t == "u-boot"} {
			cmd_uboot $cmd $rsp
			
		} elseif {$t == "linux"} {
			cmd_linux $cmd $rsp

		} else {
			puts "Unknown command type: $t"
		}
	}
}

proc tc_prologue {tc} {

	global dry_run connected send_slow
	set send_slow {1 .050}

	if {$dry_run == "yes"} {
		return
	}

	##
	## connect to the target
	##
	if {$connected != "yes"} {

		# local VL
		connect local

		# remote
		#connect remote 
	}
}

#
# run individual TC
#
# tc: name of a test case from the l_testcases list
#
proc run_tc {tc} {

	global l_testcases
	global a_testcases

	global timeout

	##
	## header
	##
#	tc_hdr $tc
	p_banner "running test case: $tc" "#"

	##
	## pre-requisites - connection etc.
	##
	tc_prologue $tc

	##
	## uboot or linux command?
	##
	set type $a_testcases($tc,type)

	##
	## user defined timeout
	##
	if { [ array get a_testcases $tc,timeout ] > 0 } {
		p_verb "setting timeout to $a_testcases($tc,timeout)"
		set timeout $a_testcases($tc,timeout)
	}

	##
	## pre-commands (are not logged)
	##
	if { [ array get a_testcases $tc,pre ] > 0 } {
#		puts "  $a_testcases($tc,pre)"
		run_cmds a_testcases($tc,pre) $type
	} else {
#		puts "  No Pre section for a test case"
	}
	

	##
	## turn on logging
	##
	set log [ logname $tc ]
#	puts "Log file for a TC: $log"
	logon $log $type

	##
	## proper TC commands
	##
	run_cmds a_testcases($tc,commands) $type
	
	##
	## logging off
	##
	logoff 

	##
	## post-commands
	##
	if { [ array get a_testcases $tc,post ] > 0 } {
#		puts "  $a_testcases($tc,post)"
		run_cmds a_testcases($tc,post) $type
	} else {
#		puts "  No Post section for a test case"
	}

	# reset default timeout
	set timeout 10
}


proc run_tc_list {list} {

	upvar $list l

	foreach tc $l {
	#	puts "  $tc"
		run_tc $tc
	}
}




###############################################################################
# test groups processing
###############################################################################

proc duts_tg {name tcs} {

	global l_testgroups
	lappend l_testgroups $name

	global a_testgroups
	set a_testgroups($name) $tcs
}


proc show_tg_list {} {

	global a_testgroups

	foreach tg [array names a_testgroups] {
		puts "Test group: $tg"
	
		set tc_list $a_testgroups($tg)
		foreach tc $tc_list {
			puts "  $tc"
		}
		puts "\n"
	}
}

#
# returns a complete list of test cases from all test groups
#
proc tg_list {} {

	global a_testgroups

	set l_tcs [list]

	foreach tg [array names a_testgroups] {

		# list of TCs in this group
		set tc_list $a_testgroups($tg)
		foreach tc $tc_list {
			if [ regexp {^#.*} $tc] {
				# commented line starts with a hash
				continue
			}
			p_verb "  adding $tc to the list"
			lappend l_tcs $tc
		}
	}
	return $l_tcs
}


#
# check if testcases on the list are defined in the global TCs structures; if
# one or more TCs are not defined, interrupt DUTS
#
# list: _name_ of a var with list to verify
#
proc check_tc_list {list} {

	global l_testcases
	global a_testcases

	upvar $list tcl

	set missing "no"

	foreach tc $tcl {
		# look for this TC name
		if { [lsearch $l_testcases $tc] < 0 } {
			# not found..
			puts "  test case \"$tc\" NOT found?!"
			set missing "yes"
		}
	}

	if { $missing != "no" } {
		puts "\nERROR: some test case(s) not defined?!"
		exit1 "  please verify list of defined test cases with 'lt'\
		command"
	}		
}


###############################################################################
# logging
###############################################################################

proc logon {lf {t "u-boot"}} {
	
	if {$t == "u-boot"} {
		set p "=> "
	} elseif {$t == "linux"} {
		set p "bash-2.05b# "
	}
	log_file -noappend $lf
	send_user -- "$p"
}

proc logoff {} {
	send_user -- "\n"
	log_file
}

#
# produces and returns log filename for a TC
#
proc logname {tc {ext "log"}} {

	global logs_location
	global board_name

	# a TC has individual log file
	if { [ array get a_testcases $tc,logfile ] > 0 } {
		# use arbitrary log filename if specified for a TC
		set lf $board_name$a_testcases($tc,logfile)
	} else {
		# default is derived from test cases's name 
		set lf $board_name$tc.$ext
	}
	set logs [file dirname $logs_location]
	# TODO - check if dir exists, we have access etc.
#	debug "log filename: $logs/$lf"

	return "$logs/$lf"
}


#
# debug 
#
proc debug {msg {subsystem ""}} {

	# TODO debug to file

	global debugging
	if {$debugging == "yes"} {
#		set ss ($subsystem == "") ? "" "\[$subsystem\]"
		set ss ""
		puts "debug:$ss $msg"
	}
}



################
# misc
################

#
# print out error msg and exit
#
proc exit1 {msg} {
	puts "$msg"
	exit 1
}


proc niy {msg} {
	puts "WARNING: $msg is NOT implemented yet.."
}




#
# finds files with extension ext in directory dir and returns as a list, if
# recursive param present and set to "yes" we do subdirs search
#
# dir: directory
# ext: extension
#
proc find_files {dir ext {recursive "no"}} {

	if { $recursive == "yes" } {
		# unix 'find' needs to be used here, glob is to weak...
		niy "recursive find"	
	}
	
	set l_files [lsort [glob -nocomplain -dir $dir *.$ext]]
	
	if {![ llength $l_files ] > 0} {
		p_verb "No files with extension $ext in dir $dir?!"
	}
	return $l_files
}


#
# valdate directory
#
# dir: directory name
#
proc valid_dir {dir} {

	set rv 1

	if [ file exists $dir ] {
		p_verb "$dir exists"
		if [ file isdirectory $dir ] {
			p_verb "$dir is directory, OK"
		} else {
			p_err "$dir is not a directory..?!"
			set rv 0
		}
		
	} else {
		p_verb "no such directory: $dir"
		set rv 0
	}
	return $rv
}

#
# validate file
#
# f: filename
#
proc valid_file {f} {

	set rv 1

	if [ file exists $f ] {
		p_verb "$f exists"
		if [ file isfile $f ] {
			if [ file readable $f ] {
				p_verb "$f exists and accessible, OK"
			} else {
				p_err "$f not accessible..!?"
				set rv 0
			}
		} else {
			p_err "$f is not a plain file..?!"
			set rv 0
		}
	} else {
		p_err "no such file: $f"
		set rv 0
	}
	
	return $rv
}


proc load_tc_files {d {e ""}} {
	
	global TC_DESCR_EXT
	set e [ expr {($e == "") ? $TC_DESCR_EXT : $e}]
	
	foreach f [ find_files $d $e ] {
		p_verb "loading TCs from $f"

		# just sourcing the file does the trick - a_testcases hash
		# will contain details of all test cases described in the
		# files
		source $f
	}
}

#
# load common TC files
#
proc load_tcs {} {

	global tc_dir l_testcases

	if ![valid_dir $tc_dir] {
		exit1 "Invalid testcases dir: $d"
	}

	##
	## load common TCs
	##
	puts "Testcases directory: $tc_dir"
	load_tc_files $tc_dir

	set n [llength $l_testcases]
	if {$n > 0 } {
		p_verb "loaded $n test cases decriptions"
	} else {
		exit1 "No test cases descriptions loaded...?!"
	}
}

#
# load board-specific TC files
#
proc load_custom_tcs {} {

	global board_name tc_dir l_testcases

	##
	## load board specific TCs, if exitst
	##
	set d "$tc_dir/$board_name"
	if ![valid_dir $d] {
		p_verb "no target specific TCs for $board_name"	
	} else {
		load_tc_files $d

		set n [llength $l_testcases]
		if {$n > 0 } {
			p_verb "loaded $n test cases decriptions"
		} 
	}
}


#
# load TCs including custom for _all_ supported boards
#
proc load_all_tcs {} {
	#TODO
}



#
# send a single command cmd and wait for a response rsp
#
proc cmd_uboot {cmd rsp {slp 0.25}} {

#	p_verb "CMD $cmd, RSP '$rsp'"

	# clear expect's internal buffer
	expect "*"

#	set c {$cmd}

	send -s "$cmd\r"
#	send -s "$c\r"

	sleep $slp
	expect {
		-re "$rsp=>" {
#			puts "RSP OK!"
		} timeout {
			puts "timed out while waiting on cmd '$cmd'.."
			exit
		}
	}
	
#	sleep 0.25
#	expect "=>"
}	


proc cmd_linux {cmd rsp {slp 0.25}} {
	
	expect "*"
	send -s "$cmd\r"

	sleep $slp
	expect {
		-re "$rsp" {}
		timeout { exit }
	}
	
#	sleep 0.25
	expect -re "bash.*#"
}


#
# connect to board bd
# remote: yes/no - for remote VL access additional ssh/telnet logging is
#         performed
#
proc connect {{mode "local"}} {

	global board_name dry_run
	set remote [ expr {($mode == "remote") ? "yes" : "no"}] 

	if { $dry_run == "yes"} {
		puts "WARNING: no-op mode, no actions would\
		actually be performed on the target!\n"

	} else {
		# we'll be spawn'ing inside a proc, so need to have this
		# global for accessing to the forked process outside of a
		# procedure
		global spawn_id

		set send_slow {1 .050}

		# log to VL if we're remote 
		if {$remote == "yes"} {
		
			if { $dry_run != "yes"} {

				# TODO make this configurable
				# TODO process spawn error code - if not/successful
				spawn "/usr/bin/ssh" "pollux"
				expect "raj]"

				#puts "Entering interactive session.."
				#interact

				# connect to target - we have already spawn'ed
				# a ssh/telnet so only can use "send" for
				# connect (and for all commands to follow)

				send -s "connect $board_name\r"
			}
			
		} else {
			if { $dry_run != "yes"} {
				# connect to target - locally in the VL so we
				# need to spawn "connect" command

				spawn "connect" $board_name
			}
		}

		expect "using command"
		sleep 0.25
	}

	global connected
	set connected "yes"
}


