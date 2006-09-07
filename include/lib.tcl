###############################################################################
# logging test case's flow to file
###############################################################################

#
# turns on/off logging
#
# p: prompt (only needed when turning ON)
#
proc logging {onoff {lf ""}} {
	
	if {$onoff == "on"} {
		log_file -noappend $lf

	} elseif {$onoff == "off"} {
		send_user -- "\n"
		log_file
	}
}



###############################################################################
# user interface 
###############################################################################

#
# prints $msg if verbose
#
proc p_verb {msg {pfx "DUTS: "}} {
	global verbose

	if {$verbose == "yes"} {
		puts "$pfx$msg"
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

	puts ""
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
		return 0
	}
	return 1
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
# example:  if [in_array a_configs "$c,$_context_kernel"] { ... }
#
proc in_array {a k} {
	upvar $a ar
	
	if {[array get ar $k] > 0} {
		set rv 1
	} else {
		set rv 0
	}
	return $rv
}

#
# checks if element $e is found on the list $l, returns 0 if not
#
# example: if ![on_list l_configs $cn] { ... }
#
proc on_list {l e} {
	upvar $l list

	if {[lsearch $list $e] < 0} {
		set rv 0
	} else {
		set rv 1
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
# validates directory:
# - exists?
# - is dir?
# - readable?
# - writable? (when check_write flag set)
#
# dir: directory name
#
proc valid_dir {dir {check_write "0"}} {

	set rv 1

	if [file exists $dir] {
		p_verb "$dir exists"
		if [file isdirectory $dir] {
			if [file readable $dir] {
				if {$check_write} {
					if ![file writable $dir] {
						p_err "'$dir' not writable?!"
						set rv 0
					} else {
						p_verb "'$dir' exists and writable, OK"
					}
				} else {
					p_verb "'$dir' exists and accessible, OK"
				}
			} else {
				p_err "'$dir' not accessible..!?"
				set rv 0
			}
		} else {
			p_err "$dir is not a directory..?!"
			set rv 0
		}
		
	} else {
		p_err "no such directory: '$dir'"
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
				p_err "file '$f' not readable..!?"
				set rv 0
			}
		} else {
			p_err "file '$f' is not a plain file..?!"
			set rv 0
		}
	} else {
		p_err "no such file: '$f'?!"
		set rv 0
	}
	
	return $rv
}

###############################################################################
# operations on host environment
###############################################################################

#
# locates tool command on the host
#
# t - tool name e.g. bash, cg-clone
#
proc valid_host_tool {t} {
	set which_cmd "/usr/bin/which"
	set which_opt "--tty-only --show-dot --show-tilde"
	set rv 1
	
	if [file exists $which_cmd] {
		if {([file readable $which_cmd]) &&
		    ([file executable $which_cmd])} {
	
			if [catch {set o [eval exec $which_cmd $which_opt $t]}] {
				p_verb "tool '$t' not found"
				set rv 0
			} else {
				p_verb "tool '$t' OK, '$o'"
			}
		} else {
			p_err "'which' tool not accessible?!"
			set rv 0
		}
	} else {
		p_err "'which' tool not found..?!"
		set rv 0
	}
	return $rv
}

#
# checks if tools from list are available, returns logical 1/0 accordingly
#
# tools_list: NAME of the list with tools to find
#
proc check_host_tools {tools_list} {
	
	upvar $tools_list tools
	
	set rv 1
	foreach t $tools {
		if ![valid_host_tool $t] {
			p_err "command '$t' not available on host"
			set rv 0
		}
	}
	return $rv
}

#
# table of strings in the path identifying build tools similar to what we want
# to set 
#
set alike {"eldk" "crosstool" "tool"}

#
# if a piece from $alike is found in $p returns 1, otherwise 0
#
proc is_similar_path {p} {
	global alike 

	set found 0
	foreach a $alike {
		if [string match *$a* $p] {
			set found 1
		}
	}
	return $found
}

#
# validates path p and adds it to current PATH; if similar path already exists
# it is replaced with p
#
proc set_host_tool_path {p} {

	global env

	if ![valid_dir $p] {
	        return 0
	}

	##
	## get current PATH and break it into pieces
	##
	set path $env(PATH)
	set pl [split $path ":"]
	set pl_new {}

	##
	## look for path to similar tools already present in the PATH, if we
	## found such replace them with ours
	##
	set len [llength $pl]
	for {set i 0} {$i < $len} {incr i} {
        	set el [lindex $pl $i]
		if [is_similar_path $el] {
        	        # there's already a path to build tools - change it to
			# our newly desired path
                	set pl_new [lreplace $pl $i $i $p]
			break
        	}
	}
	if [llength $pl_new] {
        	set path_new [join $pl_new ":"]
	} else {
        	# if there is no updated path list it means there was no other
		# build tools path found in the current PATH so we need to add
		# ours
        	lappend pl $p
	        set path_new [join $pl ":"]
	}
	# now we can set the [new] PATH
	set env(PATH) $path_new

	return 1
}

#
# spawns bash shell on host, returns its $spawn_id
#
proc host_bash_shell {{prompt ""} {opt ""}} {

	# for bash shell ignore user rc files so we can be sure of the default
	# prompt
	set def_opt "--norc --noprofile"
	set def_p "\\$\\ "

	set c "bash"
	if ![valid_host_tool $c] {
		exit1
	}
	set o [expr {($opt == "") ? $def_opt : "$opt $def_opt"}]
	set p [expr {($prompt == "") ? $def_p : "$prompt"}]

	##
	## spawn host shell
	##
	set timeout 4

	set spawn_id [process_spawn $c $o]
	if {$spawn_id < 0} {
		p_err "problems spawning shell" 1
	}
	# Notice: we HAVE to wait for the initial prompt of the just spawned
	# shell! otherwise we wouldn't know when to issue the command...
	expect {
		-re "$p$" { p_verb "host shell prompt OK" }
		timeout { p_err "timed out waiting for prompt: '$p'" 1 }
	}
	send_user -- "\n"

	return $spawn_id
}

#
# copies $s to $d, conditions like access rights etc. are assumed to be checked
# by the caller
#
proc host_copy {s d} {

	if ![valid_file $s] {
		return 0	
	}
	set c "cp $s $d"
	if [catch {set o [eval exec $c]}] {
		p_err "copy command failed: '$c'"
		return 0
	}
	
	return 1
}

###############################################################################
# process mgmt 
###############################################################################

#
# spawns process and returns spawn_id or -1 
#
proc process_spawn {p {params ""}} {
	if {$p == ""} {
		return -1 
	}
	
	if [catch {set sid [eval spawn -noecho $p $params]}] {
		p_verb "couldn't spawn '$p'"
		return -1
	}
	return $spawn_id
}

#
# closes spawned process
#
proc process_close {sid} {
	if {$sid == ""} {
		return
	}
	close -i $sid
	wait -i $sid
}

###############################################################################
# user interface options handling
###############################################################################
#
# - there are two global structures required:
# 
#   1. opt_table -  table of user interface options, has to be created
#   manually; each element is:
#
#   {<global_var_name> "<opt_string>" "<default_value>"}
#
#   2. opt_list - helper list of all options strings (<opt_string>'s from the
#   opt_table), gets created automatically in opt_create_globals{}
#
#
# - usage: 
#
#   1. provide opt_table structure
#   2. call opt_create_globals{} to initialize everything
#   3. use opt_process{} in your params parsing routine
# 
#

#
# options handling init routine, it creates:
# - global variables from options table and assigns default values; vars do
# not need to exist or be initialized on the global level as will get created
# automatically here.
#
# - global list with option strings for further easier access to defined
# options' strings
#
proc opt_create_globals {} {
	global opt_table opt_list

	foreach o $opt_table {
		set var_name [lindex $o 0]
		set opt_str [lindex $o 1]
		set def_val [lindex $o 2]

		# set global var - note we 'dereference' a variable by its 
		# name - hence the $ in set's first argument is needed
		global $var_name
		set $var_name $def_val
		
		# add opt string to the list
		lappend opt_list $opt_str
	}
}

#
# checks if option's value empty, returns 1 if so
#
proc opt_val_empty {o_val {pfx "-"}} {

	set r "^$pfx.*"
	if {([regexp $r $o_val]) || ($o_val == "")} {
		return 1
	}
	return 0
}

#
# processes one option: verifies the value $o_val to be assigned is valid, and
# if so finds out a global var for this option and sets it to the value
#
# o_txt: option string - has to match <opt_string> from options table
# o_val: value to be assigned for this option
# check_list: if set checks if option found on the global list
#
# returns 1 if successful, 0 when problems
#
proc opt_process {o_txt o_val {check_list "0"}} {

	global opt_table opt_list
	set rv 1

	# strip off possible leading "-"
	if [regexp {^-.*} $o_txt] {
		set o_txt [string trimleft $o_txt "-"]
	}

	if {$check_list} {
		# return failed if option not recognized 
		if ![on_list opt_list $o_txt] {
			return 0
		}
	}

	# get global var associated with option
	foreach o $opt_table {
		if {$o_txt == [lindex $o 1]} {
			set o_var [lindex $o 0]
			break
		}
	}

	if [opt_val_empty $o_val] {
		p_err "option '$o_txt' requires value"
		set rv 0
	}

	# set the global with supplied value: we 'dereference' a variable by
	# its name - hence the $ in argument is needed
	global $o_var
	set $o_var $o_val 

	# to get the var value we need to force substitution
	p_verb "$o_txt = '[subst $$o_var]'"

	return $rv 
}