#!/bin/sh
# the next line restarts using tclsh \
    exec tclsh "$0" ${1+"$@"}

# leg20180315
# (c) 2018 Georg Lehner <jorge-odmon@at.anteris.net>
# Share and use it as you like, but don't blame me-

set version 0.3

package require Tk
package require http
package require tls
http::register https 443 [list ::tls::socket]

set commandline ""

set config(confdir) [file join ~ .config onedrive]

set config(OneDrive,clientId) "22c49a0d-d21c-4792-aed1-8f163c982546"
set config(OneDrive,scope) "user.read files.readwrite files.readwrite.all offline_access"

set config(access_timeout) 0

set dock_photo_data "R0lGODdhFAAUAKECABh0zR13zv///////ywAAAAAFAAUAAACQZSAqRZolt5xD0gqod42V9iFVXSJ
5TJuoIKxlPvCK6uisgeOdl6jx4ojTXQ8D2nhmxwjMNdM1wSenEqccvfJJHUFADs="

# Libraries

proc slurp f {set f [read [set f [open $f]]][close $f]}
proc spit {f data} {
    puts -nonewline [set f [open $f w]] $data
    close $f
}
#
# z-base-32
#
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
#
# JSON
#
# taken from ton version 0.4
namespace eval ton {}
proc ton::json2ton json {
    set i [trr $json [string length $json]]
    if {!$i} {return ""}
    lassign [jscan $json $i] i ton
    if {[set i [trr $json $i]]} {
	error "json string invalid:[incr i -1]: left over characters."
    }
    return $ton
}
proc ton::trr {s i} {
    while {[set j $i] &&
	   ([string is space [set c [string index $s [incr i -1]]]]
	    || $c eq "\n")} {}
    return $j
}
proc ton::jscan {json i {d :}} {
    incr i -1
    if {[set c [string index $json $i]] eq "\""} {
	str $json [incr i -1]
    } elseif {$c eq "\}"} {
	obj $json $i
    } elseif {$c eq "\]"} {
	arr $json $i
    } elseif {$c in {e l}} {
	lit $json $i
    } elseif {[string match {[0-9.]} $c]} {
	num $json $i $c $d
    } else {
	error "json string end invalid:$i: ..[string range $json $i-10 $i].."
    }
}
proc ton::num {json i c d} {
    set float [expr {$c eq "."}]
    for {set j $i} {$i} {incr i -1} {
	if {[string match $d [set c [string index $json $i-1]]]} break
	set float [expr {$float || [string match "\[eE.]" $c]}]
    }
    set num [string trimleft [string range $json $i $j]]
    if {!$float && [string is entier $num]} {
	    list $i "i $num"
    } elseif {$float && [string is double $num]} {
	list $i "d $num"
    } else {
	error "number invalid:$i: $num."
    }
}
proc ton::lit {json i} {
    if {[set c [string index $json $i-1]] eq "u"} {
	list [incr i -3] "l true"
    } elseif {$c eq "s"} {
	list [incr i -4] "l false"
    } elseif {$c eq "l"} {
	list [incr i -3] "l null"
    } else {
	set e [string range $json $i-3 $i]
	error "literal invalid:[incr i -1]: ..$e."
    }
}
proc ton::str {json i} {
    for {set j $i} {$i} {incr i -1} {
	set i [string last \" $json $i]
	if {[string index $json $i-1] ne "\\"} break
    }
    if {$i==-1} {
	error "json string start invalid:$i: exhausted while parsing string."
    }
    list $i "s [list [string range $json $i+1 $j]]"
}
proc ton::arr {json i} {
    set i [trr $json $i]
    if {!$i} {
	error "json string invalid:0: exhausted while parsing array."
    }
    if {[string index $json $i-1] eq "\["} {
	return [list [incr i -1] a]
    }
    set r {}
    while {$i} {
	lassign [jscan $json $i "\[,\[]"] i v
	lappend r \[$v\]
	set i [trr $json $i]
	incr i -1
	if {[set c [string index $json $i]] eq ","} {
	    set i [trr $json $i]
	    continue
	} elseif {$c eq "\["} break
	error "json string invalid:$i: parsing array."
    }
    lappend r a
    return [list $i [join [lreverse $r]]]
}
proc ton::obj {json i} {
    set i [trr $json $i]
    if {!$i} {
    	error "json string invalid:0: exhausted while parsing object."
    }
    if {[string index $json $i-1] eq "\{"} {
	return [list [incr i -1] o]
    }
    set r {}
    while {$i} {
	lassign [jscan $json $i] i v
	set i [trr $json $i]
	incr i -1
	if {[string index $json $i] ne ":"} {
	    error "json string invalid:$i: parsing key in object."
	}
	set i [trr $json $i]
	lassign [jscan $json $i] i k
	lassign $k type k
	if {$type ne "s"} {
	    error "json string invalid:[incr i -1]: key not a string."
	}
	lappend r \[$v\] [list $k]
	set i [trr $json $i]
	incr i -1
	if {[set c [string index $json $i]] eq ","} {
	    set i [trr $json $i]
	    continue
	} elseif {$c eq "\{"} break
	error "json string invalid:$i: parsing object."	
    }
    lappend r o
    return [list $i [join [lreverse $r]]]
}
# original: ton::a2dict
foreach type {i d l s} {proc ton::$type v {return $v}}
proc ton::a args {
    set i -1; set r {}
    foreach v $args {lappend r [incr i] $v}
    return $r
}
proc ton::o args {return $args}
#
proc json2dict json {
    set maxlen 70
    if {[catch  {::ton::json2ton $json} ton]} {
	log error: json2dict $ton: $json
	return
    }
    set d [namespace eval ton $ton]
    dict for {key value} $d {
	if {[string length $value]>$maxlen} {
	    set value [string range $value 0 $maxlen]..
	}
	log json2dict: ${key}: $value
    }
    return $d
}
#
# REST
#
# http://wiki.tcl.tk/21624, added Authorization header and token
# refresh mechanism for Microsoft Graph API
#
namespace eval graph {
    variable graphApi https://graph.microsoft.com/v1.0
    variable redirectUrl \
	https://login.microsoftonline.com/common/oauth2/nativeclient
    variable tokenUrl \
	https://login.microsoftonline.com/common/oauth2/v2.0/token
    variable authUrl \
	https://login.microsoftonline.com/common/oauth2/v2.0/authorize

    namespace export GET
}
proc graph::requestAuthorization {} {
    global config
    variable authUrl
    variable redirectUrl
    log trying to launch browser with the following url:
    set url $authUrl?client_id=$config(OneDrive,clientId)&
    append url scope=$config(OneDrive,scope)&response_type=code&
    append url redirect_uri=$redirectUrl
    log $url
    log Copy the resulting URL from the Browser to the 'Authorize' text entry and press the button again.
    if {[catch {exec x-www-browser $url} err]} {
	log Error: $err
    } else {
	log browser launched.
    }
}
proc graph::Authorize url {
    global config
    variable redirectUrl
    variable tokenUrl


    set query [lindex [split $url ?] 1]
    set code ""
    foreach p [split $query &] {
	lassign [split $p =] k v
	if {$k eq "code"} {
	    set code $v
	    break
	}
    }
    if {![string length $code]} {
	log Error: no authentication code find in response url.
	return
    }    
    set query [http::formatQuery \
		   client_id $config(OneDrive,clientId) \
		   redirect_uri $redirectUrl \
		   code $code \
		   grant_type authorization_code
	      ]
    set token [http::geturl $tokenUrl -query $query]
    set result [http::data $token]
    http::cleanup $token
    set result [json2dict $result]
    set config(access_token) [dict get $result access_token]
    set expiry [dict get $result expires_in]
    set config(access_timeout) [expr {[clock seconds] + $expiry}]
    log (re)writing refresh_token
    if {[catch {spit \
		    [file join ~ .config onedrive odopen_token] \
		    [dict get $result refresh_token]} \
	     err]} {
	log Error: could not write odopen_token: $err
    }
}
proc graph::RefreshToken {} {
    global config
    variable redirectUrl
    variable tokenUrl
    
    set query [http::formatQuery \
		   client_id $config(OneDrive,clientId) \
		   redirect_uri $redirectUrl \
		   refresh_token $config(token)\
		   grant_type refresh_token
		  ]
    set token [http::geturl $tokenUrl -query $query]
    set result [http::data $token]
    http::cleanup $token
    set result [json2dict $result]
    set config(access_token) [dict get $result access_token]
    set expiry [dict get $result expires_in]
    set config(access_timeout) [expr {[clock seconds] + $expiry}]
    return $result
}
proc graph::ExtractError tok {return [http::code $tok],[http::data $tok]}
proc graph::OnRedirect {tok location} {
    variable graphApi
    upvar 1 url url
    set url $location
    set where $location
    if {[string equal -length [string length $graphApi/] $location $graphApi/]} {
	set where [string range $where [string length $graphApi/] end]
	return -level 2 [split $where /]
    }
    return -level 2 $where
}
proc graph::DoRequest {method url {type ""} {value ""}} {
    global config
    for {set reqs 0} {$reqs < 5} {incr reqs} {
	if {[info exists tok]} {
	    http::cleanup $tok
	}
	if {[clock seconds] >= $config(access_timeout)} RefreshToken
	set headers [list Authorization "Bearer $config(access_token)"]
	foreach v {method url headers method type value} {
	    log $v: [set $v]
	}
	set tok [http::geturl $url \
		     -headers $headers -method $method \
		     -type $type -query $value]
	if {[http::ncode $tok] > 399} {
	    set msg [ExtractError $tok]
	    http::cleanup $tok
	    return -code error $msg
	} elseif {[http::ncode $tok] > 299 || [http::ncode $tok] == 201} {
	    set location {}
	    if {[catch {
		set location [dict get [http::meta $tok] Location]
	    }]} {
		http::cleanup $tok
		error "missing a location header!"
	    }
	    OnRedirect $tok $location
	} else {
	    set s [http::data $tok]
	    http::cleanup $tok
	    return $s
	}
    }
    error "too many redirections!"
}
proc graph::GET args {
    variable graphApi
    DoRequest GET $graphApi/[join $args /]
}
proc graph::POST {args} {
    variable graphApi
    set type [lindex $args end-1]
    set value [lindex $args end]
    set m POST
    set path [join [lrange $args 0 end-2] /]
    DoRequest $m $graphApi/$path $type $value
}
# proc graph::PUT {args} {
#     variable graphApi
#     set type [lindex $args end-1]
#     set value [lindex $args end]
#     set m PUT
#     set path [join [lrange $args 0 end-2] /]
#     DoRequest $m $graphApi/$path $type $value
# }
# proc graph::DELETE args {
#     variable graphApi
#     set m DELETE
#     DoRequest $m $graphApi/[join $args /]
# }
#
# GUI
#
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

#
#  GUI - New Drive Configuration
#

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

    set host [lindex [split [dict get $odopen webUrl] /] 2]
    set siteId [string range [dict get $odopen siteId] 1 end-1]
    set webId [string range [dict get $odopen webId] 1 end-1]

    set listId [string range [dict get $odopen listId] 1 end-1]

    graph::GET \
	sites [join [list $host $siteId $webId] ,] \
	lists $listId \
	drive
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
    
    set spOrg $config(OneDrive,org,displayName)

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
	file copy [file join $config(confdir) refresh_token] $config($drive,confdir)
	set f [open [file join $config($drive,confdir) config] a]
	puts $f "# odopen [clock format [clock seconds] -format {%+}]
#
sync_dir = \"$config($drive,syncdir)\"
drive_id = \"$config($drive,driveId)\"
"
	close $f
    } else {
	# remove from memory so we can check again.
	foreach key [array names config $drive,*] {
	    unset config($key)
	}
    }

}

proc addDriveFromUrl url {

    log Parsing odopen url:
    set odopen_dict [odopen2dict $url]
    foreach {key value} $odopen_dict {
	log ${key}: $value 
    }

    log Getting drive data:
    set drive_data [getDriveData $odopen_dict]

    configDrive $odopen_dict [json2dict $drive_data]
    
}
#
# GUI - Authorization procedure
#
proc authorize {} {
    if {[string length $::authorize_url]} {
	graph::Authorize $::authorize_url
	set $::authorize_url ""
	getUserData
	getOrgData
    } else {
	graph::requestAuthorization
    }
}
#
# GUI - Command interpreter
#
proc repl {} {
    log % $::commandline
    catch {uplevel #0 $::commandline} result
    log $result
    set ::commandline ""
}

namespace import graph::*

proc get args {
    json2dict [graph::GET {*}$args]    
    return
}
#
# GUI - main panel
#
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
    wm title . odopen
    wm iconphoto . [image create photo -data $::dock_photo_data]
    
    # https://wiki.tcl.tk/9984
    bindtags . [list . bind. [winfo class .] all]

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
    pack [button $w.parse -text "odopen?" \
	      -command {addDriveFromUrl $odopen_url}] -side left
    pack [entry $w.url -relief sunken -bd 2 -textvariable odopen_url -width 60] \
	-side left -expand 1 -fill x

    # Authorization helper frame
    pack [set w [frame .authz]] -fill x
    pack [button $w.parse -text "Authorize" -command authorize] -side left
    pack [entry $w.url -relief sunken -bd 2 -textvariable authorize_url -width 60] \
	-side left -expand 1 -fill x


    # Bottom combo
    pack [set w [frame .bottom]] -fill both -expand 1
    
    # info frame
    pack [set f [frame $w.info]] -fill x

    #   me
    pack [label $f.me_label -text me:] -side left
    pack [label $f.me  -width 30 -anchor w \
	      -textvariable config(OneDrive,me,displayName)] -side left

    #  organization
    pack [label $f.org_lebel -text Organization:] -side left
    pack [label $f.org -width 8 -anchor w \
	      -textvariable config(OneDrive,org,displayName)] -side left
    
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
	      -xscrollcommand [list $w.hscroll set] \
	      -height 20 ] \
	-expand 1 -fill both

    set config(odopen,logWidget) $w.log

    focus .line.commandline
}
#
# Start Up
#
proc getUserData {} {
    global config

    log get user data..
    set d [json2dict [graph::GET me]]
    foreach key {displayName givenName surName mail userPrincipalName} {
	if {[catch {dict get $d $key} value]} {
	    set value ""
	}
	set config(OneDrive,me,$key) $value
    }
    
    # If there is no display name, try to construct one
    #  from firstname lastname
    if {![string length $config(OneDrive,me,displayName)]} {
	append config(OneDrive,me,displayName) \
	    $config(OneDrive,me,givenName) \
	    " " \
	    $config(OneDrive,me,surName)
    }
    #  or from the email address
    if {$config(OneDrive,me,displayName) eq " "} {
	set config(OneDrive,me,displayName) \
	    [lindex [split $config(OneDrive,me,mail) @] 0]
    }
}
proc getOrgData {} {
    global config
    log get organization data..
    log Note: we are only processing the first entry, there might be more...
    set d [json2dict [graph::GET organization]]
    if {[catch {dict get $d value 0 displayName} org]} {
	log Error: could not get name of organization, setting to OneDrive.
	set org OneDrive
    }
    set config(OneDrive,org,displayName) $org
}
#
# commandline processing
#
proc options opts {
    global config
    if {[llength $opts]>1} {
	log Error: invalid commandline: $opts
	return
    }
    if {[llength $opts]==1} {
	set config(opts,url) [lindex $opts 0]
    }
}
#
# main
#
proc main opts {
    global config

    screen
    options $opts
    if {[catch {slurp [file join $config(confdir) odopen_token]} token]} {
	log Error no odopen_token file: $token.
	log Info: you need to 'Authorize' before you can do anything else.
    } else {
	log authCode: $token
	set config(token) $token
	getUserData
	getOrgData
    }
    if {[info exists config(opts,url)]} {
	addDriveFromUrl $config(opts,url)
    }
}

main $argv

# Emacs:
# Local Variables:
# mode: tcl
# End:
