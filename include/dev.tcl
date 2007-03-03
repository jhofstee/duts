###############################################################################
##
## device processing routines
##
###############################################################################

set was_common_device "no"
set device_errors 0

#
# called when .tgt file is source'd
#
proc duts_device {name args} {

	global cur_device was_common_device DEVICE_COMMON_NAME
	global l_boards device_errors

	set cur_device $name
	
	if {$name == $DEVICE_COMMON_NAME} {
		if {$was_common_device == "yes"} {
			p_verb "$DEVICE_COMMON_NAME re-defined?!"
		} else {
			set was_common_device "yes"
		}
	}

	lappend l_boards $name
	
	p_verb "Loading device description for: $cur_device"
	uplevel 1 [lindex $args end]

	if {$device_errors > 0} {
		exit1
	}
}


#
# processes Internals section in duts_device description
#
# p: path to the tcl script with implementation of required methods, note the
# path is relative to $working_dir
#
proc Internals {p} {
#	global cur_device a_devices device_errors working_dir
	global cur_device a_devices device_errors BASE_DIR
	
	##
	## validate file
	##
	set f "$BASE_DIR/$p"
	if ![valid_file $f] {
		p_err "problems validating file: $f"
		set device_errors 1
	} else {
		# is this used anywhere later?
		set a_devices($cur_device,internals) $p
		
		set err ""
		if [catch {source $f} err] {
			p_err "problems with source'ing '$f'?!"
			puts "  $err"
			set device_errors 1
		}
	}
}

#
# processes MakeTarget/Arch/Compile section in duts_device description
#
proc make {type p} {
	global cur_device a_devices

	set a_devices($cur_device,make$type) $p
}

proc MakeTarget {p} {
	make "target" $p
}

proc MakeArch {p} {
	make "arch" $p
}

proc MakeCompile {p} {
	make "compile" $p
}

proc MakeToolPath {p} {
	make "toolpath" $p
}

#
# processes Vars section in duts_device description
#
proc Vars {vars} {

	global board_name cur_device DEVICE_COMMON_NAME a_devices

	if {($cur_device != $board_name) && 
	    ($cur_device != $DEVICE_COMMON_NAME)} {
		# do not parse and set global vars for boards other than
		# currently selected or _common
		return
	}

	##
	## parse Vars section, all definitions are converted to global
	## variables that are (potentially) later used
	##

	# numer of lines in the section
	set max [expr [llength $vars] - 1]

	# TODO verify max is even, otherwise the Vars section is broken

	set l_vars ""
	for {set i 0} {$i < $max} {incr i 2} {
		# var name 
		set var [lindex $vars $i]

		# value assigned
		set val [lindex $vars [expr $i + 1]]

#puts "varname $var\t value $val"
		global $var
		set $var $val
		lappend l_vars $var
	}
	
	p_verb "set globals: $l_vars"
	
	##
	## save the list of [global] vars set for this board, so we can
	## retrieve them later
	##
	if [llength $l_vars] {
		set a_devices($cur_device,varlist) $l_vars
	}
}

#
# Retrieves attribute for the current board, or the _common device.
#
proc get_device_attr {a} {
	global a_devices board_name DEVICE_COMMON_NAME
	set rv ""
	
	if ![in_array a_devices "$board_name,$a" ] {
		if ![is_device_common_defined $a ] {
			p_err "attribute '$a' not found for device\
			      '$board_name'" 1

		} else {
			p_verb "attribute '$a' found for common device, OK"
			set rv $a_devices($DEVICE_COMMON_NAME,$a)
		}
	} else {
		p_verb "attribute '$a' defined for device '$board_name', OK"
		set rv  $a_devices($board_name,$a)
	}

	return $rv
}

#
# checks if entry $ent for _common section is defined in a_devices array,
# returns 1 if found, 0 otherwise
#
proc is_device_common_defined {ent} {
	global a_devices DEVICE_COMMON_NAME

	set rv 0
	if {[in_array a_devices "$DEVICE_COMMON_NAME,$ent"]} {
		set rv 1
	}

	return $rv
}

#
# checks if entry $ent for board $b is defined in
# a_devices array, returns 1 if found, 0 otherwise
#
proc is_device_board_defined {b ent} {
	global a_devices

	set rv 0
	if {[in_array a_devices "$b,$ent"]} {
		set rv 1
	}

	return $rv
}


#
# validates devices are consistent:
#
# - if mandatory device methods are implemented
# - if all boards have Vars sections - warn, this may turn to problems later
#
proc valid_devices {} {

	global a_devices l_boards board_name

	set rv 1

	set mandatory_methods {_device_power_on _device_power_off\
				_device_connect_target _device_connect_host}

	foreach mm $mandatory_methods {
		if ![proc_exists $mm] {
			p_err "method '$mm' not found?!"
			set rv 0
		} else {
			p_verb "method '$mm' found, OK"
		}
	}

	foreach b $l_boards {
		##
		## warn about possible problems (not mandatory sections etc.)
		##
		if ![is_device_board_defined $b "varlist"] {
			if ![is_device_common_defined "varlist"] {
				p_warn "no section Vars (or empty)!?"
			}
		}
	}

	##
	## verify make params are present
	##
	set makeparams {MakeTarget MakeArch MakeCompile MakeToolPath}
	foreach mp $makeparams {
		set mpp [string tolower $mp]
		if ![in_array a_devices "$board_name,$mpp" ] {
			if ![is_device_common_defined $mpp ] {
				p_verb "make param '$mp' not found?!"
			} else {
				p_verb "common make param '$mp'"
			}
		}
	}

	return $rv
}

#
# loads device description files
# 
# e: extension
#
proc load_all_devices {{e ""}} {

	global working_dir board_name l_boards
	global DEVICE_DESCR_DIR DEVICE_DESCR_EXT DEVICE_COMMON_FILE
	global BASE_DIR
	
#	set d "$working_dir/$DEVICE_DESCR_DIR"
	set d "$BASE_DIR/$DEVICE_DESCR_DIR"
	if ![valid_dir $d] {
		p_err "Invalid device dir: $d" 1
	}

	set e [expr {($e == "") ? $DEVICE_DESCR_EXT : $e}]

	#
	# try load a _common device description before any others
	#
	set f "$d/$DEVICE_COMMON_FILE"
	if [valid_file $f] {
		p_verb "loading common devices description '$f'"
		if [catch {source $f} err] {
			p_err "could not parse common device file: '$f'"
			puts "  $err"
			exit1
		}
	}

	foreach f [find_files $d $e] {
		# skip common device file
		if {[file tail $f] == $DEVICE_COMMON_FILE} {
			continue
		}

		p_verb "loading devices from $f"

		# just sourcing the file does the trick - a_devices hash
		# will contain details of all device descriptions in the
		# files
		set err ""
		if [catch {source $f} err] {
			p_err "problems with parsing '$f'?!"
			puts "  $err"
			exit1
		}
	}

	set n [llength $l_boards]
	if {$n > 0} {
		p_verb "loaded $n device decriptions"
		
		##
		## validate devices
		##
		if ![valid_devices] {
			exit1
		}
		
	} else {
		p_err "No device descriptions found in '$d' dir?!" 1
	}
}


proc list_all_devices {} {
	global l_boards DEVICE_COMMON_NAME

	puts "Defined configurations for the devices:"
	foreach b $l_boards {
		if {$b == $DEVICE_COMMON_NAME} {
			# don't show the shared device on the list
			continue
		}
		puts "  $b"
	}
	puts ""
}


#
# shows device details for the $board_name
#
proc show_device {} {
	global board_name a_devices

	puts "Configuration for board: $board_name"
	if [catch {set vl $a_devices($board_name,varlist)}] {
		set vl ""
	}
	if [catch {set t $a_devices($board_name,maketarget)}] {
		set t ""
	}
	if [catch {set a $a_devices($board_name,makearch)}] {
		set a ""
	}
	if [catch {set c $a_devices($board_name,makecompile)}] {
		set c ""
	}
	if [catch {set c $a_devices($board_name,maketoolpath)}] {
		set c ""
	}
	puts "  vars set: $vl"
	puts ""
	puts "  make params: target '$t' arch '$a' ccompile '$c'"
	puts ""
}
