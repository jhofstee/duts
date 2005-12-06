###############################################################################
# logging test case's flow to file
###############################################################################

#
# turns on/off logging
#
# p: prompt (only needed when turning ON)
#
proc logging {onoff {lf ""} {p ""}} {
	
	if {$onoff == "on"} {
		log_file -noappend $lf
		send_user -- "$p "

	} elseif {$onoff == "off"} {
		send_user -- "\n"
		log_file
	}
}


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
#	debug "log filename: $logs/$lf"

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
		p_err "board $board_name NOT known?! Use 'c' command for list\
		       of supported devices"
	} else {
		p_verb "board $board_name found, OK"
		set rv 1
	}
	return $rv
}


#
# prints $msg if verbose
#
proc p_verb {msg} {
	global verbose

	if {$verbose == "yes"} {
		puts "DUTS: $msg"
	}
}

#
# prints warning
#
proc p_warn {msg} {
	puts "WARNING: $msg"
}

#
# prints error message and possibly exits
#
# msg: message
# exit: if "1" causes to stop execution
#
proc p_err {msg {exit "0"}} {
	puts "ERROR: $msg"
	if {$exit == "1"} {
		exit1
	}
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
#
#
proc ask_yesno {msg} {
	set timeout -1
	send_user "$msg\[y] "
	expect_user -re "(.*)\n" {
		set ans $expect_out(1,string)
	}
	if {$ans != "y" && $ans != ""} {
		exit
	}
	set timeout 10
}

#
# print out error msg and exit
#
proc exit1 {{msg ""}} {
	if {$msg != ""} {
		puts "$msg"
	}
	exit 1
}


proc niy {msg} {
	puts "WARNING: $msg is NOT implemented yet.."
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


#
# returns the name of the CALLING proc
#
proc proc_name {} {

	set cur_level [info level]
	set name [lindex [info level [expr $cur_level - 1]] 0]
	set self_name [lindex [info level 0] 0]

	if {$name == $self_name} {
		# called from the main script level 
		set name "MAIN"
	}
	return $name
}

#
# checks if procedure exists, returns 0 if not
#
# p: proc name
#
proc proc_exists {p} {
	set rv 1

	if ![llength [info procs $p]] {
		set rv 0 
	}
	return $rv
}

#
# checks if element $k is found in array $a, returns 0 if not
#
# a: name of array (NOT the array itself!)
# k: key
#
proc in_array {a k} {
	upvar $a ar
	
	set rv 1
	if {[ array get ar $k ] > 0} {
#		p_verb "key '$k' found, OK"
	} else {
#		p_verb "key '$k' not found in array"
		set rv 0
	}
	return $rv
}

#
# checks if element $e is found on the list $l, returns 0 if not
#
proc on_list {l e} {
	upvar $l list
	set rv 1
	if {[lsearch $list $e] < 0} {
#		p_verb "element '$e' not found on list"
		set rv 0
	} else {
#		p_verb "element '$e' found, OK"
	}
	return $rv
}

###############################################################################
# files operations
###############################################################################

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
# valdates directory
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
# validates file
#
# f: filename
#
proc valid_file {f} {

	set rv 1

	p_verb "validating: '$f'"
	if [file exists $f] {
		if [file isfile $f] {
			if [file readable $f] {
				p_verb "file exists and accessible, OK"
			} else {
				p_err "file not accessible..!?"
				set rv 0
			}
		} else {
			p_err "file is not a plain file..?!"
			set rv 0
		}
	} else {
		p_err "file '$f' not found?!"
		set rv 0
	}
	
	return $rv
}

#
# runs external [expect] script
#
# fn: filename with respect to the DUTS working dir
#
proc run_external_script {fn} {
	global working_dir

	set f [string trimleft $fn "!"]
	set f "$working_dir/$f"

	if ![valid_file $f] {
		p_err "problems with accessing file: $f" 1
	}

	p_verb "running external script $f"
	set err ""
	if [catch {source $f} err] {
		p_err "problems with source'ing '$f'?!"
		puts "  $err"
		exit1
	}
}
