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

###############################################################################
#
# test cases (TC) processing routines 
#
# the following globals are required to exist (must be created by the "calling"
# layer)
#
# l_testcases 
# a_testcases 
# cur_tc
#
###############################################################################

proc duts_tc {name args} {
	global cur_tc l_testcases a_testcases tc_filename
	set cur_tc $name

	lappend l_testcases $name

	uplevel 1 [lindex $args end]

	# check if we have mandatory sections
	if {![in_array a_testcases "$name,commands"]} {
		p_err "section 'Commands' NOT defined for '$name' TC?!" 1
	}

	# save the filename the TC lives in
	set a_testcases($cur_tc,filename) $tc_filename
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
# shows list of all test cases
#
proc show_tc_list {} {

	global l_testcases
	global a_testcases

	foreach tc $l_testcases {

		puts "  $tc, $a_testcases($tc,type)"

		if {[in_array a_testcases "$tc,info"]} {
#			puts "  $a_testcases($tc,info)"
		} else {
#			puts "  No description for a test case"
		}
	}
	puts -nonewline "\n"
}

#
# shows details of a testcase
#
# tc: name of a TC
#
proc show_tc_details {tc} {

	global l_testcases a_testcases

	##
	## look for this TC name
	##
	if { [lsearch $l_testcases $tc] < 0 } {
		# not found..
		p_err "  test case \"$tc\" NOT found?!" 1
	}

	##
	## show TC details
	##
	puts "Testcase '$tc' details:"
	puts "  Type:\t\t$a_testcases($tc,type)"
	if {[in_array a_testcases "$tc,pre"]} {
		puts "  Pre:\t\t$a_testcases($tc,pre)"
	}
	puts "  Commands:\t$a_testcases($tc,commands)"
	if {[in_array a_testcases "$tc,post"]} {
		puts "  Post:\t\t$a_testcases($tc,post)"
	}
	puts "  Filename:\t$a_testcases($tc,filename)"
}

#
# runs a sequence of commands for a TC
#
# cmds: commands/responses struct
# ctx: context [class] of the TC
#
proc run_cmds {cmds ctx} {

	global dry_run board_name a_devices DEVICE_COMMON_NAME
	set result 1
	upvar $cmds c
	
	#
	# if we have global vars set for the board make them available
	# locally
	#
	if [catch {set common_varlist $a_devices($DEVICE_COMMON_NAME,varlist)}] {
		p_warn "no _common section or no variables set"
		set common_varlist ""
	}
	if [catch {set board_varlist $a_devices($board_name,varlist)}] {
		p_warn "no variables set in board '$board_name' config"
		set board_varlist ""
	}

	set l_vars [concat $common_varlist $board_varlist]
	
	foreach v $l_vars {
#		p_verb "global'ling $v"
		global $v
	}
	# this is a built-in keyword often used - add it to the var list
	set BOARD $board_name
	lappend l_vars "BOARD"

#puts "RUN: $cmds"
#puts "CMDS:\n$c"

	# number of elements 
	set max [expr [llength $c] - 1]

	if {$max == 0} {
		set c [lindex $c 0]
		# there's only one argument - check if we have an external
		# script to execute
		set res 1
		if [regexp {^\!.*} $c] {
			set res [run_external_script $c]
			# we allow only one special (external) TC
		#	return

		} else {
			set res 0
			p_warn "command '$c' seems broken, skipping..."
		#	return 0
		}
		p_verb "external script result: $res"
		return $res
	}
	
	for {set i 0} {$i < $max} {incr i 2} {
		##
		## command
		##
		set cmd [lindex $c $i]
		
		#
		# we need to force vars substitution (subst) as there can be 
		# $ vars defined and used for commands
		#
		if [string match "*$\{*" $cmd] {
			p_verb "U-Boot vars found, skip forced substitution"
		} else {
			# try force subst - we may have VARs used in command
			if [catch {set cmd [subst $cmd]}] {
				p_err "substitution failed on the following:"
				puts "  $cmd"
				set result 0
				continue
			}
		}

		##
		## expected response
		##
		set rsp [lindex $c [expr $i + 1]]
		
		if [regexp {^#.*} $cmd] {
			# commented line starts with a hash
			incr i
			continue
		}

#puts [format "  CMD: %s, RSP: %s" $cmd $rsp]

		if {$dry_run == "yes"} {
			p_warn "dry run activated, skipping '$cmd' command"
			continue	
		}

		if {[string length $cmd] == 0} {
			p_warn "empty command..."
			continue	
		}

		##
		## Time to execute command.
		##
		set res 0
		if {$ctx == "firmware"} {
			set res [_context_firmware_command $cmd $rsp]
			
		} elseif {$ctx == "kernel"} {
			set res [_context_kernel_command $cmd $rsp]

		} elseif {$ctx == "host"} {
			set res [_context_host_command $cmd $rsp]

		} else {
			p_err "unknown context '$ctx' required?!" 1
		}

		p_verb "Command result: $res"
		# a single command failure means failure of the whole sequence
		if {$res == 0} {
			set result 0
		}
	}

	return $result
}


#
# prepares environment for the TC execution
#
# tc: test case
# ctx: context class required for the TC
#
proc tc_prologue {tc ctx} {

	global dry_run 

#	if {$dry_run == "yes"} {
#		return
#	}

	global cur_context send_slow spawn_id
	global connected console_con control_con

	set send_slow {1 .050}

	if {$ctx == "host"} {
		set cur_context $ctx

		# we don't need to connect to target or switch device's 
		# contexts in case of operations on host, so we're done with 
		# the prologue
		return
	}

	##
	## establish console/control connection(s)
	##
	if {$connected != "yes"} {

#p_banner "CONS connection"

		# connect to devices' console
		set console_con [_device_connect_target]
#		p_verb "CONS connection set, OK"

		set connected "yes"
		
		# have console connection spawn_id be the global default
		set spawn_id $console_con
		expect "*"
	}

	## 
	## try identify if the declared cur_context is really what device
	## actually is, this might be not easy at all...
	##
	set real_context [_device_current_context]
	if {$real_context != $cur_context} {
		p_verb "adjusting current context '$cur_context' to: '$real_context'"
		set cur_context $real_context
	}


	##
	## bring the board to the required state
	##
	if {$ctx != $cur_context} {
		context_switch $ctx
	} else {
		p_verb "context already set, no action"
	}
}

#
# runs individual TC
#
# tc: name of a test case from the l_testcases list
#
proc run_tc {tc} {

	global l_testcases a_testcases TIMEOUT
	global timeout cur_context

	set rv 1

	##
	## header
	##
	p_banner "running test case: $tc" "#"

	##
	## context of the TC (like u-boot or linux) 
	##
	set ctx $a_testcases($tc,type)
	
	# get _class_ of the context [implementation] required by the TC (as the
	# state machine only knows the classes like firmware and kernel, not
	# their current implementation like u-boot/linux)
	set context [context_class $ctx]
	p_verb "current context: '$cur_context', required by the TC:\
	'$ctx \($context\)'"

	##
	## user defined timeout
	##
	if {[in_array a_testcases "$tc,timeout"]} {
		p_verb "setting timeout to $a_testcases($tc,timeout)"
		set timeout $a_testcases($tc,timeout)
	}

	##
	## pre-requisites, context changes etc.
	##
	tc_prologue $tc $context

	##
	## pre-commands (are not logged)
	##
	if {[in_array a_testcases "$tc,pre"]} {
		p_verb "running commands from Pre section"
		if ![run_cmds a_testcases($tc,pre) $context] {
			p_err "problems while executing Pre section"
			set rv 0
		}
	} else {
		p_verb "no Pre section for test case '$tc'"
	}
	

	##
	## turn on logging
	##
	set log [logname $tc]
	logging "on" $log

	##
	## proper TC commands
	##
	if ![run_cmds a_testcases($tc,commands) $context] {
		p_err "problems while while executing test cases"
		set rv 0
	}
	
	##
	## logging off
	##
	logging "off"

	##
	## post-commands
	##
	if {[in_array a_testcases "$tc,post"]} {
		if ![run_cmds a_testcases($tc,post) $context] {
			p_err "problems while while executing Post section"
			set rv 0
		}
	} else {
		p_verb "no Post section for test case '$tc'"
	}

	# reset default timeout
	set timeout $TIMEOUT

	return $rv
}


#
# runs test cases from a list
#
# ln: name of a list
#
proc run_tc_list {ln} {
	
	global board_name working_dir

	upvar $ln l
	set testsystem_name [file tail $working_dir]

	##
	## Open a summary logfile.
	##
	set rfn "${board_name}_${testsystem_name}_results.log"
	if [catch {set rf [open $rfn w+]} err] {
		p_err "problems open'ing '$rfn'"
		puts "  $err"
		exit1
	}

	##
	## Run TCs from the list, for each put an entry to a result log
	## indicating whether we passed or failed.
	##
	foreach tc $l {
		set res [run_tc $tc]
		set result [expr {($res == 0) ? "FAIL" : "PASS"}]
		puts $rf "$tc:\t\t\t $result"
	}
	
	close $rf

	p_banner "finished processing test cases" "#"
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

	if {$missing != "no"} {
		p_err "\nsome test case(s) not defined?!"
		exit1 "  please verify list of defined test cases with 'lt'\
		command"
	}		
}


#
# loads TCs from an individual .tc file
#
# f - can be a full path to the file or just a TC file name within current
# testsystem's 'testcases' subdir i.e. specified by one of the following
# convetions:
#
#   - ./duts -v t luan testsystems/dulg/testcases/01_flash.tc
#   - ./duts -v t luan 01_flash.tc
#
proc load_tc_file {f} {

	global tc_filename working_dir TC_DESCR_DIR

	if ![valid_file $f] {
		#
		# Problem with the file - give it a 2nd chance and search for
		# it in the 'testcases' subdir, in case it was not the full
		# path.
		#
		set d "$working_dir/$TC_DESCR_DIR"
		if ![valid_dir $d] {
			p_err "Invalid testcases dir: $d" 1
		}
		set f2 "$d/$f"
		
		if ![valid_file $f2] {
			# All failed, give up.
			p_err "could not access TC file '$f'" 1
		} else {
			set f $f2
		}
	}

	set tc_filename $f
	if [catch {source $f} err] {
		p_err "problems with parsing '$f'?!"
		puts "  $err"
		exit1
	}
}

proc load_all_tc_files {d {e ""}} {
	
	global tc_filename
	global TC_DESCR_EXT
	set e [ expr {($e == "") ? $TC_DESCR_EXT : $e}]
	
	foreach f [find_files $d $e] {
		p_verb "loading TCs from $f"

		# some other modules make use of current TC name
		set tc_filename $f

		# just sourcing the file does the trick - a_testcases hash
		# will contain details of all test cases described in the
		# files
		set err ""
		if [catch {source $f} err] {
			p_err "problems with parsing '$f'?!"
			puts "  $err"
			exit1
		}

	}
}

#
# load test cases from files
#
proc load_tcs {} {

	global working_dir l_testcases TC_DESCR_DIR

	set d "$working_dir/$TC_DESCR_DIR"
	
	if ![valid_dir $d] {
		p_err "Invalid testcases dir: $d" 1
	}

	##
	## load common TCs from all files with TC descriptions
	##
	puts "Testcases directory: $working_dir"
	load_all_tc_files $d

	set n [llength $l_testcases]
	if {$n > 0 } {
		p_verb "loaded $n test cases decriptions"
	} else {
		p_err "No test cases descriptions loaded...?!" 1
	}
}

#
# load board-specific TC files
#
proc load_custom_tcs {{b ""}} {

	global board_name working_dir l_testcases TC_DESCR_DIR

	set b [ expr {($b == "") ? $board_name : $b}]

	##
	## load board specific TCs, if exitst
	##
	set d "$working_dir/$TC_DESCR_DIR/$b"
	if ![valid_dir $d] {
		p_verb "no target specific TCs for $b"	
	} else {
		load_all_tc_files $d

		set n [llength $l_testcases]
		if {$n > 0 } {
			p_verb "loaded $n test cases decriptions"
		} 
	}
}

proc load_all_test_cases {} {
	load_tcs
	load_custom_tcs
}
