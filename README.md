odmon - The ondrive monitor
===========================

(c) 2018 Georg Lehner <jorge-odmon@at.anteris.net>

Share and use it as you like, but don't blame me.


What is it
----------

[onedrive][] is a command line application, capable of syncing the
files of a Microsoft OneDrive account.  We have
[created patches][our_onedrive] which allow for better selection of
what to sync and syncing drives shared via Office 365 Enterprise or
Education.

The *onedrive* program only syncs one drive at once, but you can run
several instances of *onedrive* to sync several drives.

[odmon][] is a collection of Tcl scripts which ease the task of
configuring and running this collection of *onedrive* processes.

`odopen.tcl` Helps to create the required authorization tokens and
configures drives from SharePoint URLs

`odmon.tcl` picks up all configured drives and runs *onedrive* for
each of them.  It presents an icon in the system tray which indicates
synchronization activity and can be used to hide/unhide the main
window.


How to install
--------------

### Requisites and manual testing

*odmon* and *odopen* are single file Tcl script with all required code
included.  They need no privileges and can be run directly by hand,
without any installation procedure.

Software requisites for *odmon*:

- Debian GNU/Linux 9.3
- Patched *onedrive*
- Tcl/Tk 8.6
- tktray package - optional

It is very likely, that *odmon* will run successfully on a wide range
of variants of the above, with no or little changes.  Please report
success and failure on yours.

Requisities for the automated installation:

- make - optional for installing the application
- ImageMagick - optional for creating the application icon
- xdg-desktopmenu - optional  
  for installing the protocol handler and the menu entries
- markdown - for creating the html version of this document.


### Installation

*odmon* features support for the freedesktop.org Desktop Entry
specification and such integrates with compliant
distributions/desktops.

Copy the complete *odmon* distribution directory on your computer,
open a commandline shell and enter the directory, then run:

	sudo make install

This will copy the scripts to `/usr/local/bin`, the application icon
to `/usr/local/share/odmon/` and run `xdg-desktop-menu` with the two
desktop files for *odmon* and *odopen*.

You can tweak the `Makefile` or do all wanted steps by hand if you
have other requirements.


How to use
----------

You must have set up synchronization of your personal drive with
*onedrive* before you can use *odmon*.  This assures, that a
refresh_token and a basic configuration is present.

Alternatively, run *odopen* and 'Authorize', than symlink the file
`odopen_token` in the ondrive configuration directory to
`refresh_token`.

When you run `odmon.tcl` it will read the onedrive configuration
directory `~/.config/onedrive `and any subdirectories to collect
drives to monitor. Monitoring settings and additional drive
directories can be specified in the file
`~/.config/onedrive/odmon.conf`. Once set up, *odmon* starts
*onedrive* for each of the configured drives in the background.

If a GUI environment is detected, *odmon* provides a GUI for user
interaction and feedback, otherwise logging goes to the stderr and you
must kill *odmon* to stop it.

If the tktray package can be loaded, *odmon* installs a tray icon
which can be used to show/hide the main window (left click) and to
exit the program (double right click).

If tktray is not available the main window shows up.  If tktray is
installed and working, the *odmon* tray icon shows up in the system
tray and the *odmon* main window is hidden.  You can open the main
window with a single click, and close the application with a double
right click on the tray icon.  You will be asked for confirmation.

The main window has an 'odmon' tab, with a log window for the
application.  For each configured drive, a new tab is added. The
following GUI elements are available for interacting with the
respective drive:


### Indicators

:"pid:":
:    Shows the process id of the drive monitor.  It is an empty string
	if the monitor is not running.

:"id:":
:    Shows the drive id as used internally.  This is either 'me' for
	the personal drive or the z-base-32 encoded name of the drive.

:"dir:":
:    Shows the directory which is syncronized by this monitor.


### Actions


:"Show Log" button:
:    This button opens a terminal emulator window showing the running
	log.

:"resync"/"monitor" radiobuttons:
:    These allow to select either resync mode or standard monitoring
	mode for the next run of the monitor with the "Start"/"Stop"
	button.

:"Start"/"Stop" button:
:    When the monitor is running, the button reads "Stop" and allows
	to stop the monitor.  Otherwise, the button reads "Start" and
	allows to start the monitor.


There is a `Command:` entry box on the top of them main windows, which
allows to execute arbitrary Tcl commands inside the interpreter
running *odmon*.


The *odmon* configuration file
-------------------------------

After detecting all subdirectories of `~/.config/onedrive` *odmon*
tries to read the file `~ /.config/onedrive/odmon.conf`.  You can
disable monitoring of a specific drive and change the path of the
logfile.

It is also possible to add drives which are configured outside of
`~/.config/onedrive`, by adding a section which contains at least a
`confdir` parameter.

The following is a list of recognized parameters:

:name:
:    used as the name in the GUI

:confdir:
:    configuration directory to use for `onedrive`.  If specified in a
	section of an existing drive, this is ignored.

:logfile:
:    path to the logfile. If it is relative, it is taken relative to
	the confdir.

:skip:
:    if set to true, the drive will not be shown in the GUI and not be
	monitored by *odmon*.

:start:
:    if set to false, the drive will be shown in the GUI but it will
	not be started when *odmon* starts.

You can also set global parameters, they must come before the first
section.

:xterm:
:    a commandline string to use for the xterm, must end with -e
:    example: `xterm -T {$title} -hold -rv -e`

:window,state:
:    set to `normal` if you want to show the main window on startup


Adding new drives
-----------------

The `odopen.tcl` script is a utility to parse a SharePoint drive URL
and add a *onedrive* configuration for it.

To add a new drive, open a SharePoint website, select the `Documents`
section and click on `Synchronization`.  If you have made the
[Complete Installation] process, the browser should run *odopen*
automatically.

Otherwise you should get an error message, stating that this kind of
URL cannot be opened.  Copy the URL, which starts with
`odopen://sync?` and paste it into the entry box to the left of the
`odopen?` button, than press the button.

If everything goes well, you should be shown some technical details
and be asked if you want to add the drive.  Assent and (re)start
*odmon*.

There is a `Command:` entry box on the top of them main windows, which
allows to execute arbitrary Tcl commands inside the interpreter
running *odopen*.


Status of *odmon*
-----------------

*odmon* is a bunch of hastily glued together routines.  Since you
already read the license, there is no need to overstress that it is
your fault if you loose data or anything consequential by using
*odmon*.

At this moment a lot of desirable fancy features are missing and I
have left interactive debugging features in the GUI, so I can play
around to see how to implement them.  This makes the programs somewhat
ugly and unelegant; ok, better let's say they are nerdy.

That said, *odmon* does it's basic job in my environment.  No effort
has been put into *odmon* to make it resiliant to failure conditions
like network interruptions or unexpected responses from the Microsoft
Graph API.

I'll be more then happy to receive feedback and adapt *odmon* to a
broader range of environments.

**Plug**: Tip me if you want to improve *onedrive* or *odmon* but
cannot or do not want to do it by yourself.

ToDo
----

* Add stats/info about each drive on the respective *odmon* drive tab.
* Add abililty to enable/disable syncronization of each drive.
* Add abillity to re-read configuration, so we can dinamically
  add/remove drives.
* Make robust, if not production ready.
* Add ability to process any `odopen://` URL we can get our hands on.
* Test and port for OS X and Microsoft Windows.
* Feed back some issue to *onedrive* especially make it behave better
  for logging, sync feedback and make GUI based authorization possible
  or easier.
* Rewrite either *onedrive* in Tcl or *odmon* in D.
* Decide about a future *onedrive* architecture so it either
  * does multiple syncs by itself or
  * factors out some data


How things are done
-------------------

### Synchronization directory

*odmon* tries to mimic the OneDrive for Business clients' convention
for naming the directories to be synced.  If we have the following
data:

* Business/Organization where the user account is registered: ORG
* SharePoint site name: SITE
* Name of the document collection (drive) to be synced: DOCS

Then the directory: `~/ORG/SITE - DOCS` will be configured for
synchronization.


### Configuration directory

Each additional drive is configured as a sub directory of
`~/.config/onedrive`, the latter is the *onedrive* default
for the personal drive.

The directory name is the `SITE` string, encoded with z-base-32 which
is pure lowercase ASCII, so any string for `SITE` will work out.
Unincidentially lowercase also happens to be a requirement for Tk
window names (lowercase).

The z-base-32 encoder/decoder implementation is rather keen: don't use
it on large volumes of data.  It is also untested.


### Microsoft GraphAPI

The authentication to the Microsoft GraphAPI was done by hijacking
both the *onedrive* clientId and the refresh token, maintained by the
personal drive configuration of *onedrive*.  We don' t even have to
fake the User-Agent string. Easy, isn't it?

Currently we only hijack the clientId and handle the refresh token
ourselves, since we need more privileges in *odopen*, in order to read
the Organization name.

We use the *ton* JSON parser, see this [post][ton].  if you want to
know something about it.


### Dock and window Icon

The *odmon* icon was drawn with The Gimp. It is meant to represent
white, cloudy O, D an M letters in front of a OneDrive blueish sky.

ODM is OneDriveMonitor, you guessed it, and I am lousy at design, am I
not?

The image is exported to a `.gif` file which is then base64
encoded. The resulting string is copy/pasted into the code and
provides the window and task bar icon.

For the system tray icon the image is converted to black/white, the
colors are inverted and it is exported as a standard `.xbm` file.  The
contents of this file is copy/pasted into the code.


Credits
-------

All credits go to skillion for *onedrive* and to Jon Ousterhout and
fellows for Tcl/Tk and the incredible Tlcer's Wiki.  Thanks to Per
Öberg for his feedback on the very first version.


[onedrive]: https://github.com/skilion/onedrive/
class="external"

[our_onedrive]: https://github.com/jorge-leon/onedrive
class="external"

[odmon]: http://at.magma-soft.at/darcs/odmon

[ton]:
http://at.magma-soft.at/sw/blog/posts/Reverse_JSON_parsing_with_TCL/

