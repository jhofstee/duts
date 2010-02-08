#
# (C) Copyright 2008-2010 Detlev Zundel <dzu@denx.de>, DENX Software Engineering
# (C) Copyright 2006, 2007 Rafal Jaworowski <raj@semihalf.com> for DENX Software Engineering
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
# misc
###############################################################################

#
# validates board name: checks if name found on the list of all boards
#
# bn: board name, if empty take global $board_name
#
proc valid_board_name {{bn ""}} {

	global board_name l_boards

	if {$bn == ""} {
		set bn $board_name
	}
	if {[lsearch $l_boards $bn] < 0} {
		return 0
	} else {
		return 1
	}
}


#
# runs external [expect] script
#
# fn: filename with respect to the DUTS working/testcases dir
#
proc run_external_script {fn {vars ""} } {
	global testsystem dry_run TC_DESCR_DIR

	set f [string trimleft $fn "!"]
	set f "$testsystem/$TC_DESCR_DIR/$f"
	set rv 1

	if ![valid_file $f] {
		p_err "problems with accessing file: $f"
		return 0
	}

	p_verb "running external script $f"
	if  {$dry_run == "yes"} {
		p_warn "dry run activated, skipping execution of '$f'"
	} else {
		foreach v $vars {
			p_verb "global'ling $v"
			global $v
		}
		set err ""
		set ret 0
		if [catch {set ret [source $f]} err] {
			p_err "problems with source'ing '$f'?!"
			puts "  $err"
			set rv 0
		}
		set rv $ret
	}

	return $rv
}

#
# sends the contents of a file via send_user.  This is handy to
# dump files into duts logfiles
#
proc send_user_file {fn} {
	if ![valid_file $fn] {
		p_err "problems accessing file: '$fn'"
		return 0
	}

	if [catch {set f [open $fn r]} err] {
		p_err "problems open'ing '$fn'"
		puts "  $err"
		return 0
	}

	while {[gets $f line] >= 0} {
		send_user -- "$line\n"
	}

	close $f
}
