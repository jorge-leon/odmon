# odmon - The ondrive monitor

(c) 2018 Georg Lehner <jorge-odmon@at.anteris.net>

Share and use it as you like, but don't blame me-


## What is it

[onedrive](https://github.com/skilion/onedrive/) is a command line
application, capable of syncing the files of a Microsoft OneDrive
account.  We have
[created patches](https://github.com/jorge-leon/onedrive) which allow
for better selection of what to sync, and to sync drives shared via
Office 365 Enterprise or Education.

The *onedrive* program only syncs one drive at once, but you can run
several instances of *onedrive* to sync several drives.

[*odmon*](http://at.magma-soft.at/darcs/odmon) is a Tcl script, which
picks up all configured drives and runs odmon* for each of them.  It
presents an icon in the system tray which indicates synchronization
activity and can be used to hide/unhide the main window.

*odmon* also allows to configure additional drives.


## How to install

*odmon* is a single Tcl script, just copy it to your disk and run it.

Requisites:

- Debian GNU/Linux 9.3
- Patched *onedrive*
- Tcl/Tk 8.6
- tktray package

It is very likely, that *odmon* will run successfully on a wide range
of variants of the above.


## How to use

You must have set up synchronization of your personal drive with
*onedrive* before you can use *odmon*.  This assures, that a
refresh_token and a basic configuration is present.

When running *odmon* successfully, the main window pops up, it shows
two tabs: `odmon` which is the main log window, and `OneDrive`, which
holds a log window for the synchronization of your personal drive.

A tray icon with the cloudishly distorted letters O, D and M should be
visible in the system tray.  If you click on the icon, the main window
hides, if you click again, the main window appears.

To add a new drive, open a SharePoint website, select the `Documents`
section and click on `Synchronization`.  You should get an error
message, stating that this kind of URL cannot be opened.  Copy the
URL, which starts with `odopen://sync?` and paste it into the entry
box to the left of the `odopen?` button.

If everything goes well, you should be shown some technical details
and be asked if you want to add the drive.  Assent. A new tab with the
name of the SharePoint group is added and the files are synchronized to
a sub directory of `~/UCAN/`.

**Note:** The log windows will eat up all available memory in short
time.  This can be mitigated but not avoided by clearing the log
windows with the respective `Clear` buttons of the tabs.  Either close
and reopen *odmon* now and then, or nag me to rewrite *odmon*.

There is a `Command:` entry box on the top of them main windows, which
allows to execute arbitrary Tcl commands inside the interpreter
running *odmon*.


## What is the status of odmon

*odmon* is a bunch of hastily glued together routines. This is the
first release to the public, because it does the most basic things
needed to take advantage of our *onedrive* patches and people have
asked for it.

Since you read the license, I do not need to over stress that it is
your fault if you loose data or anything consequential by using
*odmon*.

Tk8.6 leaks memory in the listbox widget we are using for the log
windows and we do nothing to trim the logs either.  The UX of *odmon*
is designed to explore *onedrive* and OneDrive, so this is currently a
marginal problem.  It will go away, either when everything works, or
somebody goes into the length of working around of it, probably by
eliding the log functionality in the user interface.

Some important things ToDo:

* Make robust, if not production ready.
* Add ability to process any `odopen://` URL we can get our hands on.
* Find out how to get the organizations name.
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


## How are things done

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

The authentication to the Microsoft GraphAPI is done by hijacking
both the *onedrive* clientId and the refresh token, maintained by the
personal drive configuration of *onedrive*.  We don' t even have to
fake the User-Agent string. Easy, isn't it?


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


# Credits

All credits go to skillion for *onedrive* and to Jon Ousterhout and
fellows for Tcl/Tk.
