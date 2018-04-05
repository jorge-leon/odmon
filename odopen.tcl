#!/usr/bin/wish

# leg20180315
# (c) 2018 Georg Lehner <jorge-odmon@at.anteris.net>
# Share and use it as you like, but don't blame me-

set version 0.1.2

package require Tk
package require http
package require tls

lappend auto_path [file join [pwd] ton]
set config(use_json2dict) [catch {package require ton}]

set commandline ""

set config(window,state) normal

set config(clientId) "22c49a0d-d21c-4792-aed1-8f163c982546"

set config(me,access_timeout) 0

foreach {label url} {
    authUrl https://login.microsoftonline.com/common/oauth2/v2.0/authorize
    redirectUrl https://login.microsoftonline.com/common/oauth2/nativeclient
    tokenUrl https://login.microsoftonline.com/common/oauth2/v2.0/token
    itemByIdUrl https://graph.microsoft.com/v1.0/me/drive/items/
    itemByPathUrl https://graph.microsoft.com/v1.0/me/drive/root:/
    driveByIdUrl https://graph.microsoft.com/v1.0/drives/
    driveUrl https://graph.microsoft.com/v1.0/me/drive
    siteUrl https://graph.microsoft.com/v1.0/sites/
} {
    set config(OneDrive,url,$label) $url
}

set dock_photo_data "R0lGODdhFAAUAKECABh0zR13zv///////ywAAAAAFAAUAAACQZSAqRZolt5xD0gqod42V9iFVXSJ
5TJuoIKxlPvCK6uisgeOdl6jx4ojTXQ8D2nhmxwjMNdM1wSenEqccvfJJHUFADs="


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

set config(drives) me
set config(me,name) OneDrive
set config(me,confdir) [file join ~ .config onedrive]
# find drive directories
foreach drive [glob -nocomplain \
	       -types d -tails -dir [file join ~ .config onedrive] *] {
    if {[z-base-32-check $drive]} {
	lappend config(drives) $drive
	set config($drive,confdir) [file join ~ .config onedrive $drive]
	set config($drive,name) [string trimright [z-base-32-decode $drive] \0]
    }
}


# Tcl
proc set* {var args} {uplevel set $var [list $args]}

###proc clear textWidget {$textWidget delete 0.0 end}
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

proc log args {logto $::config(odopen,logWidget) {*}$args}


set config(onedrive,changelog,strings) {
    {[M] *}
    {Uploading file *}
    {Uploading fragment: *}
    {Trying to restore the upload session ...}
    {Continuing the upload session ...}
    {Deleting *}
}

proc new_drive drive {
    global config
    
    log new_drive $drive

    set* cmd onedrive --confdir $config($drive,confdir) -m -v
    if {[catch {open "| [join $cmd] 2>@1" r+} f]} {
	log error " " $f 
	return
    }
    set config($drive,chan) $f
    set config($drive,PID) [pid $f]
    set config($drive,uploading) false

    set logdest [new_drive_tab $drive]


    logto $logdest $cmd 
    
    fconfigure $f -blocking false
    fileevent $f readable [list logpipeto $f $logdest]

    if {[catch {open [file join $config($drive,confdir) refresh_token] r} f]} {
	log Error no refresh_token file for drive: $drive, $f
	close $config($drive,chan)
	remove_drive $drive
	return
    }
    set config($drive,token) [read $f]
    close $f

    log token for $drive: $config($drive,token) 

    # monitor memory info
    #every 3000 [list logMemInfo $config($drive,PID)]
    
    lappend config(drives) $drive
}

proc url_prefix_helper {arrName index op} {
    lassign [array get $arrName $index] dummy key
    lassign [split $index ,] drive url_prefix_key
    array set $arrName [list $drive,url_prefix $::config(OneDrive,url,$key)]
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

    #   token
    pack [label $w.token_label -text token:] -side left

    pack [label $w.token -textvariable ::config($drive,token) -width 40] \
	-side left -fill x -expand 1
    
    # tools frame
    pack [set w [frame .tabs.$drive.tools]] -fill x

    # forward reference    
    pack [button $w.clear -text Clear \
	      -command [list clear .tabs.$drive.log.text]] \
	-side left
    
    # geturl frame
    pack [set w [frame .tabs.$drive.geturl]] -fill x

    set tags {}
    foreach key [array names ::config OneDrive,url,*] {
	lappend tags [string range $key [string length OneDrive,url,] end]
    }
    
    tk_optionMenu $w.url_prefix_key ::config($drive,url_prefix_key) {*}$tags]

    pack [label $w.url_prefix_url -textvariable ::config($drive,url_prefix)] -side left

    trace add variable ::config($drive,url_prefix_key) write url_prefix_helper
        
    # log frame
    pack [set w [frame .tabs.$drive.log]] -expand 1 -fill both
    
    pack [scrollbar $w.hscroll -command [list $w.text xview] \
	      -orient horizontal] \
	-side bottom -fill x
    pack [scrollbar $w.vscroll -command [list $w.text yview]] \
	-side right -fill y
    pack [listbox $w.text -relief sunken -bd 2 \
	      -yscrollcommand [list $w.vscroll set] \
	      -xscrollcommand [list $w.hscroll set]] \
	-expand 1 -fill both
    
    set config($drive,logWidget) .tabs.$drive.log.text
}

proc remove_drive drive {
    global config
    
    log remove_drive $drive
    foreach name [array names config $drive,*] {
	unset config($name)
    }
    # remove drive from drive list
    # http://wiki.tcl.tk/15659
    set config(drives) [lsearch -all -inline -not -exact $config(drives) $drive]

    destroy .tabs.$drive
}

proc add_button {name label command} {
    button .top.$name -text $label -command $command
    pack .top.$name -side left -padx 0p -pady 0 -anchor n
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
	puts stderr "$chan closed"
    }
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
    wm title . odopen
    wm iconphoto . [image create photo -data $::dock_photo_data]
    
    # close channels/kill subprocesses when closing odopen
    # https://wiki.tcl.tk/9984
    bindtags . [list . bind. [winfo class .] all]
    bind bind. <Destroy> reap

    # top frame
    pack [set w [frame .top -borderwidth 10]] -fill x

    # Commandline frame
    pack [set w [frame .line]] -fill x
    
    pack [label $w.label -text Command:] -side left
    pack [entry $w.commandline -relief sunken -bd 2 -textvariable commandline] \
	-side left -expand 1 -fill x
    bind $w.commandline "<Return>" repl

    # intermezzo to get back/foreground color
    set config(label,background) [$w.label cget -background]
    set config(label,foreground) [$w.label cget -foreground]

    
    # drive_id extractor frame
    pack [set w [frame .odopen]] -fill x
    pack [button $w.parse -text "odopen?" -command logOdopenResult] -side left
    pack [entry $w.url -relief sunken -bd 2 -textvariable odopen_url] \
	-side left -expand 1 -fill x

    # Tabs
    pack [ttk::notebook .tabs] -expand 1 -fill both

    # odopen frame
    set w [frame .tabs.odopen]
    .tabs add $w -text odopen

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
	      -command {clear $config(odopen,logWidget)}] \
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

    set config(odopen,logWidget) $w.log

    focus .line.commandline
}


foreach drive $config(drives) {after idle new_drive $drive}

screen


# http://wiki.tcl.tk/9299
proc every {ms cmd} {
    {*}$cmd
    after $ms [list after idle [info level 0]]
}

proc logMemInfo pid {
    global config
    
    set* cmd pmap -q $pid
    if {[catch {open "| [join $cmd] 2>@1" r} f]} {
	log Error: running pmap $pid: $f 
	return
    }
    if {[gets $f line]==-1} {
	log Error: getting first line of pmap $pid
	close $f
	return
    }
    set config(pmap,$pid,commandline) $line
    set config(pmap,$pid,mem) 0
    log pmap: checking $line 
    while {[gets $f line]!=-1} {
	set line [string map {\[ "" \] ""} $line]
	lassign $line addr mem rw process
	set mem [string range $mem 0 end-1]; # strip trailing K
	incr config(pmap,$pid,mem) $mem
	if {[info exists config(pmap,$pid,$addr,mem)]} {
	    if {$mem != $config(pmap,$pid,$addr,mem)} {
		log $line 
		log pmap: $pid $config(pmap,$pid,$addr,process): \
		    $config(pmap,$pid,$addr,mem) -> $mem 
		set config(pmap,$pid,$addr,mem) $mem
	    }
	} else {
	    foreach item {mem rw process} {
		set config(pmap,$pid,$addr,$item) [set $item]
	    }
	}
    }
    close $f    
}

# To track own memory usage log memory consumption with pmap [pid] regularily
every 30000 [list logMemInfo [pid]]


# http
http::register https 443 [list ::tls::socket]

if {$config(use_json2dict)} {
    # https://wiki.tcl.tk/13419
    proc json2dict JSONtext {
	string range [
		      string trim [
				   string trimleft [
						    string map {\t {} \n {} \r {} , { } : { } \[ \{ \] \}} $JSONtext
						   ] {\uFEFF}
				  ]
		     ] 1 end-1
    }
} else {
    # ton
    proc json2dict json {
	set maxlen 70
	if {[catch  {::ton::json2ton $json} ton]} {
	    log error: json2dict $ton: $json
	    return
	}
	set d [namespace eval ton::a2dict $ton]
	dict for {key value} $d {
	    if {[string length $value]>$maxlen} {
		set value [string range $value 0 $maxlen]..
	    }
	    log json2dict: ${key}: $value
	}
	return $d
    }
    
}

# http://wiki.tcl.tk/14144
proc url-decode str {
    set str [string map [list + { } "\\" "\\\\"] $str]
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str
    return [subst -novar -nocommand $str]
}

proc odopen2dict url {
    
    if {![string match odopen://sync\?* $url]} {
	log Error, not a OneDrive url: $url
	return
    }
    set dict {}
    foreach param [split [string range [url-decode $url] 14 end] &] {
	set i [string first = $param]
	set key [string range $param 0 $i-1]
	set value [string range $param $i+1 end]
	log $key : $value
	lappend dict $key $value
    }
    return $dict 
}

proc getDriveData odopen {
    global config

    set url $config(OneDrive,url,siteUrl)
    set host [lindex [split [dict get $odopen webUrl] /] 2]
    append url $host ,
    # get rid of {}
    set siteId [string range [dict get $odopen siteId] 1 end-1]
    append url $siteId ,
    set webId [string range [dict get $odopen webId] 1 end-1]
    append url $webId /lists/
    set listId [string range [dict get $odopen listId] 1 end-1]
    append url $listId /drive

    getMSApi $url
}

proc configDrive {sp od} {
    # sp .. dict with SharePoint site data
    # od .. dict with OneDrive data

    global config

    set driveName [dict get $sp webTitle]
    set drive [z-base-32-encode $driveName]
    log driveName: $driveName
    log drive: $drive
    if {[info exists config($drive,name)]} {
	log Warning: drive $driveName already exists, ignoring data
	tk_messageBox -icon info -type ok \
	    -title "Info!" \
	    -message "Ignoring odopen url!" \
	    -detail "drive $driveName already exists."
	return
    }
    set config($drive,name) $driveName
    set config($drive,confdir) [file join ~ .config onedrive $drive]
    set config($drive,driveId) [dict get $od id]
    
    log Warning: pending implementation: get organisation name. setting to UCAN
    set spOrg UCAN

    # wrong?: get this from od group owner information?
    set siteName [dict get $sp webTitle]
  
    set listName [dict get $od name]
    set config($drive,syncdir) [file join ~ $spOrg "$siteName - $listName"]
    set detail "Extracted drive data: \n"
    set i [string length $drive]; incr i
    foreach {key value} [array get config $drive,*] {
	log ${key}: $value
	append detail [string range $key $i end] ": " $value \n
    }
    set answer [tk_messageBox -icon question -type yesno \
		    -title "Set up Drive?" \
		    -message "Do you want to configure this drive?" \
		    -detail $detail]
    if {$answer eq "yes"} {
	file mkdir $config($drive,confdir)
	file copy [file join $config(me,confdir) refresh_token] $config($drive,confdir)
	set f [open [file join $config($drive,confdir) config] a]
	puts $f "# odopen [clock format [clock seconds] -format {%+}]
#
sync_dir = \"$config($drive,syncdir)\"
drive_id = \"$config($drive,driveId)\"
"
	close $f
	new_drive $drive
    } else {
	# remove from memory so we can check again.
	foreach key [array names config $drive,*] {
	    unset config($key)
	}
    }

}

proc logOdopenResult {} {

    log Parsing odopen url:
    set odopen_dict [odopen2dict $::odopen_url]
    foreach {key value} $odopen_dict {
	log ${key}: $value 
    }

    log Getting drive data:
    set drive_data [getDriveData $odopen_dict]

    configDrive $odopen_dict [json2dict $drive_data]
    
}

proc getMSApi url {
    global config

    if {[clock seconds] >= $config(me,access_timeout)} {
	access
    }
    set headers [list Authorization "Bearer $config(me,access_token)"]

    set token [http::geturl $url -headers $headers]
    set result [http::data $token]
    http::cleanup $token
    dict for {key value} [json2dict $result] {
	log ${key}: $value 
    }
    return $result
    
}

proc get {{url_postfix {}}} {
    
    set url $config(me,url_prefix)
    append url $url_postfix

    getMSApi $url
}


proc access {} {
    global config
    
    set query [http::formatQuery \
		   client_id $config(clientId) \
		   redirect_uri $config(OneDrive,url,redirectUrl) \
		   refresh_token $config(me,token)\
		   grant_type refresh_token
		  ]
    set token [http::geturl $config(OneDrive,url,tokenUrl) -query $query]
    set result [http::data $token]
    http::cleanup $token
    set result_data [json2dict $result]
    set config(me,access_token) [dict get $result_data access_token]
    set expiry [dict get $result_data expires_in]
    set config(me,access_timeout) [expr {[clock seconds] + $expiry}]
    return [json2dict $result]
}
