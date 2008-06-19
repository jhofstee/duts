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
## config processing routines
##
###############################################################################

set config_errors 0
set was_default_config "no"
set was_selected_config "no"
set configs_no 0

#
# called when .cfg file is source'd
#
# we're only interested in retrieving what is in _default config or in the
# selected config sections. contexts from other (non-selected) configs are
# not processed.
#
proc duts_config {name args} {

	global cur_config CONFIG_DEFAULT_NAME was_selected_config
	global config_errors was_default_config selected_config configs_no
	global l_configs

	set cur_config $name

	lappend l_configs $name

	if {$name == $CONFIG_DEFAULT_NAME} {
		if {$was_default_config == "yes"} {
			p_verb "$CONFIG_DEFAULT_NAME re-defined?!"
		} else {
			set was_default_config "yes"
		}
	}
	if {$name == $selected_config} {
		if {$was_selected_config != "yes"} {
			set was_selected_config "yes"
		}
	}

	if {($cur_config == $CONFIG_DEFAULT_NAME) ||
	    ($cur_config == $selected_config)} {

		p_verb "Loading config description: $cur_config"
		uplevel 1 [lindex $args end]

		set configs_no [incr configs_no 1]
	}

}

set _context_kernel ""
set _context_kernel_prompt ""
set _context_kernel_image ""

set _context_firmware ""
set _context_firmware_prompt ""
set _context_firmware_image ""

#
# processes context section in duts_config description. we're only interested
# in retrieving what is in _default config or in the selected config sections.
# contexts from other (non-selected) configs are not processed.
#
# the outcome are global _context_TYPE_prompt, _context_TYPE_image (where TYPE
# is 'firmware' or 'kernel') and the file from 'descr' field is soureced
#
#
proc context {type name c} {
	global cur_config config_errors BASE_DIR
	global _context_kernel _context_firmware _context_host
	global _context_kernel_prompt _context_kernel_image _context_kernel_alt_prompt
	global _context_firmware_prompt _context_firmware_image
	global _context_host_prompt _context_host_shell
	global board_name a_configs

	set a_configs($cur_config,$name) $c

	# numer of elements in context section
	set max [expr [llength $c] - 1]
	# TODO verify max is even, otherwise section is broken

	for {set i 0} {$i < $max} {incr i 2} {
		# field
		set f [lindex $c $i]

		# value
		set val [lindex $c [expr $i + 1]]
		if {$val == ""} {
			p_warn "empty value for field '$f' in '$name' context?!"
			continue
		}

		switch $f {
			"prompt" {
				set _context_${type}_prompt $val
			}
			"alt_prompt" {
				set _context_${type}_alt_prompt $val
			}
			"image" {
				# possible variable here, so need to make an
				# explicit substitution
				set BOARD $board_name
				set _context_${type}_image [subst $val]
			}
			"descr" {
				# this is a file with internal context
				# descripton - validate and source it
				set p "$BASE_DIR/$val"
				if ![valid_file $p] {
					set config_errors 1
					continue
				}

				set err ""
				if [catch {source $p} err] {
					p_err "problems with source'ing '$p'?!"
					puts "  $err"
					set config_errors 1
				}
			}
			"shell" {
				# path to the shell - only used for the host
				# context
				# TODO validate if we have this shell
				set _context_${type}_shell $val
			}
			default {
				p_err "unknown field '$f' in '$name' context\
				section?!"
				set config_errors 1
			}
		}
	}

	# set global name for the sourced context implementation
	set _context_$type $name
}


#
# these context types (classes) are currently implemented
#
proc cfg_context_firmware {name c} {
	context "firmware" $name $c
}

proc cfg_context_kernel {name c} {
	context "kernel" $name $c
}

#
# this is a special context NOT associated with operations on target devices,
# but the host machine; it allows for "test cases" that do some preparation on
# the host like code building, creating image, copying into /tftpboot location
# etc.
#
proc cfg_context_host {name c} {
	context "host" $name $c
}

#
# low-level devices handling operations
#
# p: path to the tcl script with implementation of required methods, note the
# path is relative to $working_dir
#
proc cfg_device_ops {p} {
	global cur_device a_devices device_errors BASE_DIR

	##
	## validate file
	##
	set f "$BASE_DIR/$p"
	if ![valid_file $f] {
		p_err "problems validating file: $f"
		set device_errors 1
	} else {
		set err ""
		if [catch {source $f} err] {
			p_err "problems with source'ing '$f'?!"
			puts "  $err"
			set device_errors 1
		}
	}
}

#
# validates loaded config data
#
proc valid_configs {} {
	global config_errors was_selected_config selected_config

	set rv 1
	if {$config_errors > 0} {
		set rv 0
	}
	if {$was_selected_config != "yes"} {
		p_err "selected config '$selected_config' was not found?!"
		set rv 0
	}

	##
	## check methods operating on devices
	##
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

	#TODO add other checks - if we have handler method defined etc.
	#-if _context_firmware/kernel are set and nonempty
	return $rv
}

#
# loads config description files
#
# e: extension
#
proc load_configs {{e ""}} {

	global BASE_DIR CONFIG_DESCR_DIR CONFIG_DESCR_EXT configs_no

	set d "$BASE_DIR/$CONFIG_DESCR_DIR"
	if ![valid_dir $d] {
		p_err "Invalid device dir: $d" 1
	}

	set e [expr {($e == "") ? $CONFIG_DESCR_EXT : $e}]

	foreach f [find_files $d $e] {
		p_verb "loading configs from $f"

		# just sourcing the file does the trick - a_configs hash
		# will contain details of all device descriptions in the
		# files
		set err ""
		if [catch {source $f} err] {
			p_err "problems with parsing '$f'?!"
			puts "  $err"
			exit1
		}
	}

	if {$configs_no > 0} {
		p_verb "loaded $configs_no config decriptions"

		##
		## validate
		##
		if ![valid_configs] {
			p_err "problems validating configuration descriptions" 1
		}
	} else {
		p_err "No config descriptions found in '$d' dir?!" 1
	}
}


proc list_all_configs {} {
	#TODO
}


#
# shows config details
#
proc show_config {} {
	#TODO
	niy "show individual config details"
}


#
# returns class (firwmare/kernel/host) of context $ctx
#
proc context_class {ctx} {
	global _context_firmware _context_kernel _context_host

	if {$_context_firmware == $ctx} {
		set class "firmware"
	} elseif {$_context_kernel == $ctx} {
		set class "kernel"
	} elseif {$_context_host == $ctx} {
		set class "host"
	} else {
		p_err "couldn't translate context '$ctx'?!" 1
	}
	return $class
}

#
# off -> firmware -> kernel
#          ^           |
#           \__________'
#
#
# state machine operates on state (context) classes which are implemented by
# specific context like u-boot, linux
#

#
# changes context by invoking appropriate methods
#
#
proc context_switch {ctx} {
	global cur_context dst_context

	set dst_context $ctx

	if {($cur_context == "off") &&
	    ($dst_context == "kernel")} {

		##
		## transition off->kernel needs additional stage: firmware
		## context
		##

		p_verb "switching context to intermediate: $ctx"

		# call handler
		_context_firmware_handler
		set cur_context $ctx
	}

	p_verb "switching context to: $dst_context"

	##
	## call handler of the destination context
	##
	set handler "_context_${ctx}_handler"
	$handler

	##
	## we have a new context..
	##
	set cur_context $dst_context
}

#
# This is the "virtual" get_prompt function multiplexing the methods
#
proc get_prompt {} {
	global cur_context

	if { [catch {set res [eval "_context_${cur_context}_get_prompt"] } err] } {
		p_verb "context $cur_context does not implement get_prompt!"
		return 1
	}
}
