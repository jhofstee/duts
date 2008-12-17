#!/usr/bin/tclsh
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

proc duts_tg {name tcs} {

	global l_testgroups
	lappend l_testgroups $name

	global a_testgroups
	set a_testgroups($name) $tcs
}


proc tc_skel {tc_name} {
	set tc "duts_tc $tc_name \{\n\
		\tType u-boot\n\
		\tCommands \{\n\t\t\"\" \".\*\"\n\t\}\n\}\n"

	return $tc
}

proc create_tc_skel {tgf} {

	global a_testgroups


	foreach tg [array names a_testgroups] {
		puts "Creating file: $tg.tc"

		set tc_file "$tg.tc"
		set f [open $tc_file w+ ]

		puts $f "#\n#\n# This is a skeleton TC definition file\n#\
			generated from $tgf\n#\n#\n\n"

		set tc_list $a_testgroups($tg)
		set max [expr [llength $a_testgroups($tg)]]
		foreach tc $tc_list {
			puts "  $tc"
			puts $f [ tc_skel $tc ]
		}
		puts "\n"

		close $f
	}
}




set argc [llength $argv]

if { $argc == 0 } {
	puts "Usage: $argv0 <TGfile>\n"
	exit 1
}

set tg_file [ lindex $argv 0 ]


set l_testgroups [list]
array set a_testgroups ""

source $tg_file

create_tc_skel $tg_file
