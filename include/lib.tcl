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

# "Exported functions":

# # logging test case's flow to file
# proc logging {onoff {lf ""}}
# proc parse_summary {log pass fail} {
# proc exec2 {cmd stdout stderr {monitor 0}}
# proc append_str_file {str fname}
# proc exec2_log {cmd stderr {logfile ""}}

# # user interface
# proc p_verb {msg {pfx "DUTS: "}}
# proc p_warn {msg}
# proc p_err {msg {exit "0"}}
# proc p_banner {msg {p "* "}}
# proc ask_yesno {msg}
# proc exit1 {{msg ""}}
# proc niy {msg}
# proc debug {msg {subsystem ""}}
# proc proc_name {}
# proc proc_exists {p}
# proc var_exists {v}
# proc in_array {a k}
# proc on_list {l e}

# # files operations
# proc find_files {dir ext {recursive "no"}}
# proc valid_dir {dir {check_write "0"}}
# proc valid_file {f {check_write "0"}}

# # operations on host environment
# proc valid_host_tool {t}
# proc check_host_tools {tools_list}
# proc is_similar_path {p}
# proc set_host_tool_path {p}
# proc absolutize_path {path}
# proc host_bash_shell {{prompt ""} {opt ""}}

# # process mgmt
# proc process_spawn {p {params ""}}
# proc process_close {sid}

# # user interface options handling
# proc opt_create_globals {}
# proc opt_val_empty {o_val {pfx "-"}}
# proc opt_process {o_txt o_val {check_list "0"}}


###############################################################################
# logging test case's flow to file
###############################################################################

#
# turns on/off logging
#
proc logging {onoff {lf ""}} {

	if {$onoff == "on"} {
		log_file -noappend $lf

	} elseif {$onoff == "off"} {
		send_user -- "\n"
		log_file
	}
}

#
# Parse a summary file into tests that passed and tests that failed
#
proc parse_summary {log pass fail} {
	upvar $pass p
	upvar $fail f

	if [catch {set infile [open $log "r"]} err] {
		return 0
	}

	set p {}
	set f {}
	while { [gets $infile line] >= 0 } {
		set el [regexp -inline -lineanchor -- {^(\w+):[ \t]+(\w+)$} $line]
		if { [lindex $el 2] == "PASS" } {
			lappend p [lindex $el 1]
		} else {
			lappend f [lindex $el 1]
		}
	}
	close $infile

	return 1
}

###############################################################################
# Convenience wrapper functions for exec
###############################################################################

# Execute cmd and capture stdout and stderr.  If monitor is true, pass all output
# to regular stdout
proc exec2 {cmd stdout stderr {monitor 0}} {
	upvar $stdout out
	upvar $stderr err

	if [catch {set f [open "| $cmd" r]} res] {
		return -1
	}
	set out ""
	while { [gets $f line] >= 0 } {
		if { $monitor } {
			puts $line
		}
		if { [string length $out] > 0} {
			set out "$out\n$line"
		} else {
			set out $line
		}
	}
# Only in tcl8.5 :(
#       catch {close $f} err options
#       set details [dict get $options -errorcode]
#       if {[lindex $details 0] eq "CHILDSTATUS"} {
#               return [lindex $details 2]
#       }
	if [catch {close $f} err] {
		return 1
	} else {
		return 0
	}
}

# Append a string to a file
proc append_str_file {str fname} {
	if [catch {set f [open $fname w+]} res] {
		return 0
	}
	puts $f $str
	close $f
}

# Execute command, possibly logging output, return exit status and stderr
proc exec2_log {cmd stderr {logfile ""}} {
	upvar $stderr err
	global cur_logfile

	set out ""
	set err ""

	set res [exec2 $cmd out err 1]

	# Override logfile if empty and if cur_logfile is set
	if { $logfile == ""  && [info exists cur_logfile] } {
		set logfile $cur_logfile
	}

	if { $logfile != "" } {
		append_str_file $out $logfile
	}
	return [expr $res == 0 ]
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
	puts "\nERROR: $msg"
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
# checks if variable exists, returns 0 if not
#
# v: var name
#
proc var_exists {v} {
	set rv 1
	upvar $v var

	if ![info exists var] {
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

	if {$recursive == "yes"} {
		# unix 'find' needs to be used here, glob is to weak...
		niy "recursive find"
	}

	set l_files [lsort [glob -nocomplain -dir $dir *.$ext]]

	if {!([llength $l_files]  > 0)} {
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
						p_verb "'$dir' not writable?!"
						set rv 0
					} else {
						p_verb "'$dir' exists and writable, OK"
					}
				} else {
					p_verb "'$dir' exists and accessible, OK"
				}
			} else {
				p_verb "'$dir' not accessible..!?"
				set rv 0
			}
		} else {
			p_verb "$dir is not a directory..?!"
			set rv 0
		}

	} else {
		p_verb "no such directory: '$dir'"
		set rv 0
	}
	return $rv
}

#
# validates file
#
# f: filename
#
proc valid_file {f {check_write "0"}} {

	set rv 1

	p_verb "validating: '$f'"
	if [file exists $f] {
		if [file isfile $f] {
			if [file readable $f] {
				if {$check_write} {
					if ![file writable $f] {
						p_verb "'$f' not writable?!"
						set rv 0
					} else {
						p_verb "'$f' exists and writable, OK"
					}
				} else {
					p_verb "file exists and accessible, OK"
				}
			} else {
				p_verb "file '$f' not readable..!?"
				set rv 0
			}
		} else {
			p_verb "file '$f' is not a plain file..?!"
			set rv 0
		}
	} else {
		p_verb "no such file: '$f'?!"
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
# Return absolute version of non-empty, non-absolute path.
# Assume it is relative to the pwd.
#
proc absolutize_path {path} {
	global env
	if {($path != "") && ([string index $path 0] != "/")} {
		set pwd $env(PWD)
		return "$pwd/$path"
	}
	return $path
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
