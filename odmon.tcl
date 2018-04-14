#!/bin/sh
# the next line restarts using tclsh \
    exec tclsh "$0" ${1+"$@"}

# (c) 2018 Georg Lehner <jorge-odmon@at.anteris.net>
# Share and use it as you like, but don't blame me-
# leg20180315
# leg20180320:
# - remove all http stuff for drive detection
# - remove memory monitor
# - log to file
# - remove log widget for drives
# - add button to launch tail -F in an xterm
# - try hard to find xterm executable
#
# Drive detection is now factored out from odmon.tcl, odopen.tcl is the
# original odmon.tcl and should be trimmed for drive detection.
# leg20180321:
# - can read configfile ~/.config/onedrive/odmon.conf, see sample file
#   for syntax and parameters

# ToDo:
#
# - reestablish tray icon animation via logfile filter
# - start/stop drive: use $config($drive,enable) to decide if drive has
#   to be started on program start.
# - be able to resync drive.
# - rotate logs
#
# - Add new drives
#   - by hand, giving parameters
#   - via odopen:// url from browser.
# - Configure drives via gui
#   - enable, skip
#   - directories to sync

set version 0.1.3

set commandline ""

set config(clientId) "22c49a0d-d21c-4792-aed1-8f163c982546"

set odmon_app_photo "R0lGODdhFAAUAKECABh0zR13zv///////ywAAAAAFAAUAAACQZSAqRZolt5xD0gqod42V9iFVXSJ
5TJuoIKxlPvCK6uisgeOdl6jx4ojTXQ8D2nhmxwjMNdM1wSenEqccvfJJHUFADs="

set config(X) \
    [expr {[info exists env(DISPLAY)]
	   && ![catch {package require Tk}]
       }]

if {$config(X)} {

    set config(tray,balloon,timeout) 3000; # milliseconds
    set config(tray,warn,timeout) 1000; # milliseconds

    set config(tray) [expr {![catch {package require tktray}]}]

    if {$config(tray)} {
	set config(window,state) withdrawn
    } else {
	set config(window,state) normal
    }
    
    set config(tray,warn,active) {}
    set config(tray,uploading) 0

    set config(log,xterms) {
	{xfce4-terminal -T {$title} --hold --hide-menubar --hide-toolbar -x}
	{x-terminal-emulator -T {$title} -x}
	{xterm -T {$title} -e}
	{gnome-terminal --hide-menubar -e}
	{konsole --hold --hide-menubar --hide-tabbar -e}
	{xvt -T {$title} -e}
	{rxvt -title {$title} -e}
	{mrxvt -title {$title} -hold 0x06 -e}
    }
}

### Tcl
proc set* {var args} {uplevel set $var [list $args]}

# read file into memory
proc slurp f {set f [read [set f [open $f r]]][close $f]}

# config file parser
proc iniParse {ini confVar} {
    upvar $confVar config
    set section ""
    set config(sections) {}
    set config(error) {}
    set lineo 0
    foreach line [split $ini \n] {
	incr lineo
	set line [string trim $line]
	if {![set len [string length $line]]} continue
	if {[string index $line 0] in {\# ; /}} continue
	if {$len < 3} {
	    lappend config(error) "$lineo: short line"
	    continue
	}
	if {[string index $line 0] eq "\["
	    && [string index $line end] eq "\]"} {
	    set section [string range $line 1 end-1]
	    lappend config(sections) $section
	    append section ,
	    continue
	}	
	if {[llength [lassign [split $line =] key value]]} {
	    lappend config(error) "$lineo: multiple = characters"
	    continue
	}
	set config($section[string trimright $key]) [string trimleft $value]
    }
    return
}

# z-base-32
proc z-base-32-encode str {

    binary scan $str b* bits
    if {[set rest [expr {[string length $bits]%5}]]} {
	append bits [string repeat 0 [expr {5-$rest}]]
    }
    string map {
        00000 y 00001 b 00010 n 00011 d 00100 r 00101 f 00110 g 00111 8
	01000 e 01001 j 01010 k 01011 m 01100 c 01101 p 01110 q 01111 x
	10000 o 10001 t 10010 1 10011 u 10100 w 10101 i 10110 s 10111 z
        11000 a 11001 3 11010 4 11011 5 11100 h 11101 7 11110 6 11111 9
    } $bits
}

proc z-base-32-decode str {
    binary format b* [string map {
        y 00000 b 00001 n 00010 d 00011 r 00100 f 00101 g 00110 8 00111
	e 01000 j 01001 k 01010 m 01011 c 01100 p 01101 q 01110 x 01111
	o 10000 t 10001 1 10010 u 10011 w 10100 i 10101 s 10110 z 10111
        a 11000 3 11001 4 11010 5 11011 h 11100 7 11101 6 11110 9 11111
    } $str]
}

proc z-base-32-check str {
    expr {[string map {
        y {} b {} n {} d {} r {} f {} g {} 8 {}
	e {} j {} k {} m {} c {} p {} q {} x {}
	o {} t {} 1 {} u {} w {} i {} s {} z {}
        a {} 3 {} 4 {} 5 {} h {} 7 {} 6 {} 9 {}
    } $str] eq ""}
}

if {!$config(X)} {
    proc log args {puts stderr [join $args]}
} else {
    # Log Widget
    proc clear logWidget {$logWidget delete 0 end}
    
    proc logto {destination args} {
	$destination insert end [join $args]
	$destination see end
    }
    
    proc logpipeto {chan destination {filter {}}} {
	# chan .. channel to read
	# destination .. text widget, where to append the log line
	# filter .. procedure to filter/process the log line.
	if {[gets $chan line]==-1} {
	    if {[eof $chan]} {close $chan}
	    return
	}
	if {[llength $filter]} {
	    set line [{*}$filter $destination $line]
	}
	$destination insert end $line
	$destination see end
    }

    proc log args {logto $::config(odmon,logWidget) {*}$args}
}

# log files
proc unfiltered {inch out line} {puts $out $line}

proc pipeto {drive {filter unfiltered}} {
    global config

    set inch $config($drive,chan)
    if {[gets $inch line]==-1} {
	if {[eof $inch]} {
	    close $inch
	    set config($drive,chan) {}
	}
	return
    }
    $filter $inch $config($drive,logfd) $line
}

if {$config(X)} {
    
    proc toggle_state {} {
	
	switch -- [wm state .] {
	    normal {
		wm state . withdrawn
		set config(window,state) withdrawn
	    }
	    withdrawn - iconic {
		wm state . normal
		set config(window,state) normal
	    }
	    default {
		log Error: invalid window state reported: [wm state .]
	    }
	}
    }

    proc tray {} {
	image create bitmap ::img::bitmap::tray_icon \
	    -foreground white -background DodgerBlue3 \
	    -data {
		#define tray_icon_20x20_1_width 20
		#define tray_icon_20x20_1_height 20
		static unsigned char tray_icon_20x20_1_bits[] = {
		    0x03, 0x30, 0x0e, 0xf1, 0x78, 0x0f, 0xfc, 0xdb,
		    0x0d, 0xfe, 0x9b, 0x0d, 0x0e, 0x9f, 0x0d, 0x07,
		    0x9e, 0x0d, 0x03, 0x1c, 0x00, 0x03, 0x0c, 0x00,
		    0x03, 0xec, 0x00, 0x03, 0xfe, 0x03, 0x07, 0x36,
		    0x07, 0x07, 0x37, 0x0e, 0x8f, 0x73, 0x0c, 0xfc,
		    0x63, 0x08, 0xf0, 0x60, 0x08, 0x00, 0x60, 0x08,
		    0x03, 0x60, 0x0c, 0x07, 0x30, 0x0e, 0x1f, 0xb0,
		    0x07, 0x3f, 0xfc, 0x01 };
	    }
	
	tktray::icon .tray -image ::img::bitmap::tray_icon
	
	bind .tray <Button-1> toggle_state
	bind .tray <Button-3> {shutdownInteractive true}
    }
    
    ### Tray icon animation
    proc reset_tray {} {
	global config
	
	::img::bitmap::tray_icon configure -foreground white
	set config(tray,warn,active) {}
    }
    
}

set config(onedrive,changelog,strings) {
    {[M] *}
    {Uploading file *}
    {Uploading fragment: *}
    {Trying to restore the upload session ...}
    {Continuing the upload session ...}
    {Deleting *}
}

proc notify_changes {drive destination line} {
    global config

    if {!$config(tray)}  {return $line}

    set found false
    foreach prefix $config(onedrive,changelog,strings) {
	if {[string match $prefix $line]} {
	    set found true
	    break
	}
    }
    if {!$found} {
	if {$config($drive,uploading)} {
	    set config($drive,uploading) false
	    incr config(tray,uploading) -1
	}
	if {$config(tray,uploading)==0} {
	    reset_tray
	}
	return $line
    }

    if {[llength $config(tray,warn,active)]} {
	after cancel $config(tray,warn,active)
	set config(tray,warn,active) {}
    }
    if {$prefix eq "Uploading fragment: *"} {
	::img::bitmap::tray_icon configure -foreground gold
	if {!$config($drive,uploading)} {
	    set config($drive,uploading) true
	    incr config(tray,uploading)
	}	
	return $line
    }
        
    ::img::bitmap::tray_icon configure -foreground gold
    set config(tray,warn,active) \
	[after $config(tray,warn,timeout) reset_tray]
    
    return $line
}

proc drive_config drive {
    # parse drive configuration return it as a dict and also store it
    # in the config array

    global config

    iniParse \
	[slurp [file join $config($drive,confdir) config]] \
	drive_config
    if {![info exists drive_config(sync_dir)]} {
	set drive_config(sync_dir) ~/OneDrive
    }
    set config($drive,config) [array get drive_config]
}

proc new_drive drive {
    global config
       
    if {[catch {open $config($drive,logfile) a} l]} {
	log error opening logfile, logging to stderr: $l
	set l stderr
    } else {
	fconfigure $l -buffering line
    }
    
    set* cmd onedrive --confdir $config($drive,confdir) -m -v
    puts $l "starting: [join $cmd]"

    if {[catch {open "| [join $cmd] 2>@1" r+} f]} {
	log error running monitor, giving up: $f 
	return
    }
    set config($drive,chan) $f
    set config($drive,logfd) $l
    set config($drive,PID) [pid $f]
    set config($drive,uploading) false
    set config($drive,xterm) 0; # pid of xterm process
    log [drive_config $drive]
    
    if {$config(X)} {
	set config($drive,tab) [new_drive_tab $drive]
    }
    
    fconfigure $f -blocking false
    #|| add a modified notify_changes as filter
    fileevent $f readable [list pipeto $drive]

}

proc show_log drive {
    global config

    if {![llength config(log,xterm)]} {
	log warning, no valid xterm executable,\
	    run 'tail -F $config($drive,logfile)' by yourself.
	return
    }

    if {$config($drive,xterm)
	&& ![catch {exec kill -0 $config($drive,xterm)}]
    } {
	# Note: xfce4-terminal "changes" pid, so this does not work
	#  better use xterm
	log show log for $config($drive,name):$config($drive,xterm): already running
	$config($drive,tab).tools.show_log configure -text "Running"
	return
    }
    
    set title "onedrive log: $config($drive,name)"
    set* cmd {*}[subst -nocommands $config(log,xterm)] \
	tail -F [file normalize $config($drive,logfile)]

    set config($drive,xterm) [exec {*}$cmd 2>@1 &]
    
    log show log for $config($drive,name):$config($drive,xterm): [join $cmd]
}

proc new_drive_tab drive {
    global config

    frame .tabs.$drive
    .tabs add .tabs.$drive -text $config($drive,name)

    # info frame
    pack [set w [frame .tabs.$drive.info]] -fill x

    #   pid
    pack [label $w.pid_label -text pid:] -side left
    pack [label $w.pid  -width 7 -textvariable ::config($drive,PID)] -side left
    
    #   z-base-32 id
    pack [label $w.id_label -text id:] -side left
    pack [label $w.id  -text $drive] -side left

    #   sync directory
    set dir [dict get $config($drive,config) sync_dir]
    pack [label $w.dir_label -text dir:] -side left
    pack [label $w.dir  -text [string trim $dir \"]] -side left
        
    # tools frame
    pack [set w [frame .tabs.$drive.tools]] -fill x

    #  Show log
    pack [button $w.show_log -text "Show Log" \
	      -command [list show_log $drive]] \
	-side left
    
    return .tabs.$drive
}

proc unconfig drive {
    global config
    
    foreach name [array names config $drive,*] {
	unset config($name)
    }
    # remove drive from drive list
    # http://wiki.tcl.tk/15659
    set config(drives) [lsearch -all -inline -not -exact $config(drives) $drive]
}

proc remove_drive drive {
    global config
    
    log remove_drive $drive
    destroy .tabs.$drive
    unconfig $drive
}

proc repl {} {
    log % $::commandline
    catch {uplevel #0 $::commandline} result
    log $result
    set ::commandline ""
}
	  
proc reap {} {
    foreach chan [chan names file*] {
	close $chan
    }
}

proc shutdownInteractive flag {
    if {$flag &&
	[tk_messageBox -message "Exit odmon" \
	     -icon question -type yesno \
	     -detail "Really quit?"]
	eq "no"
    } return
    reap
    exit
}

proc screen {} {
    global config
    
    # make labels selectable
    bind Label <1> {focus %W}
    
    bind Label <FocusIn> {
	%W configure -background grey -foreground white
    }
    bind Label <Double-Button-1> {
	%W configure -background grey -foreground white
	selection clear
	clipboard clear
	clipboard append [%W cget -text]
    }
    bind Label <Control-c> {
	selection clear
	clipboard clear
	clipboard append [%W cget -text]
    }
    bind Label <FocusOut> {
	%W configure \
	    -background $config(label,background) \
	    -foreground $config(label,foreground)
    }

    bind Entry <2> {%W insert insert [clipboard get]}
    
    # create main window
    wm state . $config(window,state)
    wm title . odmon
    wm iconphoto . [image create photo -data $::odmon_app_photo]
    
    wm protocol . WM_DELETE_WINDOW toggle_state

    # top frame
    pack [set w [frame .top -borderwidth 10]] -fill x

    # Commandline frame
    pack [set w [frame .line]] -fill x
    
    pack [label $w.label -text Command:] -side left
    pack [entry $w.commandline -relief sunken -bd 2 -textvariable commandline] \
	-side left -expand 1 -fill x
    bind $w.commandline "<Return>" repl

    pack [button $w.exit -text Quit \
	      -command {shutdownInteractive true}] \
	-side right

    
    # intermezzo to get back/foreground color
    set config(label,background) [$w.label cget -background]
    set config(label,foreground) [$w.label cget -foreground]

    # Tabs
    pack [ttk::notebook .tabs] -expand 1 -fill both

    # odmon frame
    set w [frame .tabs.odmon]
    .tabs add $w -text odmon

    # info frame
    pack [set f [frame $w.info]] -fill x

    #   pid
    pack [label $f.pid_label -text pid:] -side left
    pack [label $f.pid  -width 7 -text [pid]] -side left

    #  mem
    pack [label $f.mem_lebel -text mem:] -side left
    pack [label $f.mem -width 8 -textvariable config(pmap,[pid],mem)] -side left

    # Tools frame
    pack [set f [frame $w.tools]] -fill x

    pack [button $f.clear -text Clear \
	      -command {clear $config(odmon,logWidget)}] \
	-side left
        
    # log window
    pack [scrollbar $w.hscroll -orient horizontal -command [list $w.log xview]] \
	-side bottom -fill x
    pack [scrollbar $w.vscroll -command [list $w.log yview]] \
	-side right  -fill y
    pack [listbox $w.log -relief sunken -bd 2 \
	      -yscrollcommand [list $w.vscroll set] \
	      -xscrollcommand [list $w.hscroll set]] \
	-expand 1 -fill both    

    set config(odmon,logWidget) $w.log

    focus .line.commandline
}

### Main

if {$config(X)} {
    screen
    if {$config(tray)} tray
}

# personal drive
set config(drives) me
set config(names) OneDrive
set config(me,name) OneDrive
set config(me,confdir) [file join ~ .config onedrive]
set config(me,logfile) [file join ~ .config onedrive onedrive.log]
set config(me,enabled) true
set config(me,skip) false

# find drive directories
foreach drive [glob -nocomplain -types d -tails \
		   -dir [file join ~ .config onedrive] *] {
    lappend config(drives) $drive
    set config($drive,confdir) [file join ~ .config onedrive $drive]
    if {[z-base-32-check $drive]} {
	set config($drive,name) [string trimright [z-base-32-decode $drive] \0]
    } else {
	set config($drive,name) $drive
    }
    lappend config(names) $config($drive,name)
    set config($drive,enabled) true
    set config($drive,skip) false
    set config($drive,logfile) [file join $config($drive,confdir) onedrive.log]
}

# override/add with config file
proc readIniFile {} {
    global config
    
    if {[catch {slurp [file join ~ .config onedrive odmon.conf]} ini]} {
	log config file not read: $ini
	return
    }
    iniParse $ini odmConfig
    
    foreach line $odmConfig(error) {
	log config file invalid line:$line
    }
    # process global configuration
    foreach key {xterm tray,warn,timeout window,state} {
	if {[info exists odmConfig($key)]} {
	    set config($key) $odmConfig($key)
	}
    }
    
    # process sections
    if {![llength $odmConfig(sections)]} {
	log config file info: no drive configured
	return
    }
    foreach section $odmConfig(sections) {
	set present false
	if {$section in $config(drives)} {
	    set present true
	    set drive $section
	} elseif {$section in $config(names)} {
	    set present true
	    set drive [z-base-32-encode $section]
	}
	if {$present && [info exists odmConfig($section,confdir)]} {
	    log config file error: overriding confdir not allowed: $section
	}
	if {!$present} {
	    set drive [z-base-32-encode $section]
	    if {![info exists odmConfig($section,confdir)]} {
		log config file error: drive not set up, no confdir for $section
		continue
	    }
	    # set defaults
	    set confdir $odmConfig($section,confdir)
	    if {![file isdirectory $confdir]} {
		log config file error: confdir not a directory, $confdir in $section
		continue
	    }
	    set config($drive,confdir) $confdir
	    set config($drive,name) $section
	    set config($drive,logfile) [file join $confdir onedrive.log]
	    set config($drive,enabled) true
	    set config($drive,skip) false

	    lappend config(drives) $drive
	}
	foreach key {enabled logfile name skip} {
	    if {[info exists odmConfig($section,$key)]} {
		set config($drive,$key) $odmConfig($section,$key)
	    }
	}
	if {[string index $config($drive,logfile) 0] ni {/ ~}} {
	    set config($drive,logfile) \
		[file join $config($drive,confdir) $config($drive,logfile)]
	}
    }
}

readIniFile

foreach drive $config(drives) {
    if {$config($drive,skip)} {
	log skipping $config($drive,name)
	unconfig $drive
	continue
    }
    after idle new_drive $drive
}

if {$config(X)} {
    proc foundExe cmdline {
	expr {![catch {exec which [lindex $cmdline 0]}]}
    }
    proc findXterm {} {
	global config
	
	if {[info exists config(xterm)]
	    && [foundExe $config(xterm)]} {
	    set config(log,xterm) $config(xterm)
	    return
	}	
	foreach term $config(log,xterms) {
	    if {[foundExe $term]} {
		set config(log,xterm) $term
		break
	    }
	}
	if {![llength $config(log,xterm)]} {
	    log error terminal: none found
	}
    }
    findXterm

    # in case we have set it to normal in the config file
    if {$config(tray)} {wm state . $config(window,state)}
} else {
    log odmon started
    vwait forever
}

# Emacs
# Local Variables:
# mode: tcl
# End:
