odmon - The ondrive monitor
===========================

(c) 2018 Georg Lehner <jorge-odmon@at.anteris.net>

Share and use it as you like, but don't blame me.


What is it
----------

[onedrive](https://github.com/skilion/onedrive/) is a command line
application, capable of syncing the files of a Microsoft OneDrive
account.  We have
[created patches](https://github.com/jorge-leon/onedrive) which allow
for better selection of what to sync, and to sync drives shared via
Office 365 Enterprise or Education.

The *onedrive* program only syncs one drive at once, but you can run
several instances of *onedrive* to sync several drives.

[*odmon*](http://at.magma-soft.at/darcs/odmon) is a Tcl script, which
picks up all configured drives and runs *onedrive* for each of them.
It presents an icon in the system tray which indicates synchronization
activity and can be used to hide/unhide the main window.

*odopen* is a Tcl script, which has functionality for retrieving the
driveId of a shared directory in SharePoint and set it up as a new
drive for *odmon*.


How to install
--------------

### Testing

*odmon* is a single Tcl script, just copy it to your disk and run it.
The same is valid for *odopen*


Requisites:

- Debian GNU/Linux 9.3
- Patched *onedrive*
- Tcl/Tk 8.6
- tktray package - optional

It is very likely, that *odmon* will run successfully on a wide range
of variants of the above, with no or little changes.  Please report
success and failure on yours.


### Complete Installation

*odmon* now features support for the freedesktop.org Desktop Entry
specification and such integrates with compliant
distributions/desktops.  We line out, how to install *odmon* for
Debian GNU/Linux 9.3

Copy the complete *odmon* distribution directory on your computer,
open a commandline shell and enter the directory.

````
sudo cp odmon.tcl /usr/local/bin
sudo cp odopen.tcl /usr/local/bin
sudo xdg-desktop-menu install odmon-odmon.desktop
sudo xdg-desktop-menu install odmon-odopen.desktop
````

To get the icon you must have ImageMagick installed, we need the
`convert` command.  And we need of course `make`.

````
make dock_icon.gif
sudo mkdir /usr/local/share/odmon
sudo cp dock_icon.gif /usr/local/share/odmon
````

Ooops, I forgot: You **must** install *ton* and make it available to
*odmon* in order for this to work.  See the section [Status of odopen]
for instructions.

We will integrate *ton* soon into *odmon* so that no extra step will
be needed.


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

If the tktray package can be loaded, *odmon* installs a tray icon
which can be used to show/hide the main window (left click) and to
exit the program (double right click).

If tktray is not available the main window show up.

The main window has an 'odmon' tab, with a log window for the
application.  For each configured drive, a new tab with a 'Show Log'
button is added. This button opens a terminal emulator window showing
the running log.

If the system tray is working, you will get the odmon tray icon, the
*odmon* main window is hidden.  You can open the main window with a
single click, and close the application with a double right click on
the tray icon.  You will be asked for confirmation.

There is a `Command:` entry box on the top of them main windows, which
allows to execute arbitrary Tcl commands inside the interpreter
running *odmon*.


The configuration file
----------------------

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
and add a *odmon* configuration for it.

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


Status of odmon
---------------

*odmon* is a bunch of hastily glued together routines. This is the
third release to the public.

Since you read the license, I do not need to over stress that it is
your fault if you loose data or anything consequential by using
*odmon*.


Status of odopen
----------------

We used the `json2dict` oneliner from the Tcler's wiki to parse out
the driveID.  `json2dict` destroys URLs and is therefore not suited
for further development.

In order to continue `odopen.tcl` development we have "selected" the
*ton* JSON parser.  Currently you have to install it by hand, if you
want to use it:

- Download *ton* from the
  [repository](http://at.magma-soft.at/cgi-bin/darcsweb.cgi?r=ton;a=summary)

- Copy or symlink the `ton` directory as a subdirectory of the one
  where you are running `odmon.tcl`

If you want to know how and why *ton* see this
[post](http://at.magma-soft.at/sw/blog/posts/Reverse_JSON_parsing_with_TCL/).


ToDo
----

* Add stats/info about each drive on the respective *odmon* drive tab.
* Add abililty to enable/disable, stop/start syncronization of each drive.
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

**Plug**: Tip me if you want to improve *onedrive* or *odmon* but
cannot or do not want to do it by yourself.


How are things done
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

The directory name is the `SITE` string, encoded conveniently with
z-base-32 which is pure lowercase ASCII, so any string for `SITE` will
work out.  Unincidentially lowercase also happens to be a requirement
for Tk window names (lowercase).

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
