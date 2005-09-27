#!/usr/local/bin/tclsh8.4
#
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
