#
# (C) Copyright 2006, 2007 Rafal Jaworowski <raj@semihalf.com> for DENX Software Engineering
# (C) Copyright 2008 Detlev Zundel <dzu@denx.de>, DENX Software Engineering
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
# processes MakeTarget/Arch/Compile etc. section in duts_device description
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

proc MakeSrcKernelPath {p} {
	make "srckernelpath" $p
}

proc MakeObjPath {p} {
	make "objpath" $p
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
# Process Features section in duts_device description
#
proc Features {features} {
	global board_name cur_device a_devices

	set a_devices($cur_device,features) {}
	foreach f $features {
		lappend a_devices($cur_device,features) $f
	}
}

#
# Check current board for feature
#
proc has_feature {f} {
	global a_devices board_name

	return [lsearch $a_devices($board_name,features) $f]
}

#
# Checks if attribute is defined for the current board or for the _common.
#
proc is_device_attr {a} {
	global a_devices board_name DEVICE_COMMON_NAME

	if [in_array a_devices "$board_name,$a" ] {
		p_verb "attribute '$a' defined for device '$board_name'"
		return 1
	} elseif [is_device_common_defined $a ] {
		p_verb "attribute '$a' found for common device"
		return 1
	} else {
		p_verb "attribute '$a' not found for device '$board_name'"
		return 0
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
# - if all boards have Vars sections - warn, this may turn to problems later
#
proc valid_devices {} {

	global a_devices l_boards board_name
	set rv 1

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
proc show_device {board_name} {
	global a_devices

	set vl [get_device_attr "varlist"]
	set t [get_device_attr "maketarget"]
	set a [get_device_attr "makearch"]
	set c [get_device_attr "makecompile"]
	set p [get_device_attr "maketoolpath"]

	puts "Configuration for board: $board_name"
	puts "  features:"
	puts $a_devices($board_name,features)
	puts ""
	puts "  vars set:"
	foreach var [split $vl " "] {
		global $var
		eval puts "\"$var = $$var\""
	}
	puts ""
	puts "  make params:\n    target\t'$t'\n    arch\t'$a'"
	puts "    ccompile\t'$c'\n    toolpath\t'$p'"
	if [is_device_attr "makeobjpath"] {
		set obj_dir [get_device_attr "makeobjpath"]
		puts "    obj_dir\t'$obj_dir'"
	}
	puts ""
}
