# GNU Makefile for odmon
#
# (c) Georg Lehner <jorge-odmon@at.anteris.net>
# Share and use it as you like, but don't blame me.

DESTDIR=/usr/local/bin
ICONDIR=/usr/local/share/odmon

ARTEFACTS=dock_icon.gif dock_icon.xbm README.html

BINS=odmon.tcl odopen.tcl
XDGS=odmon-odmon.desktop odmon-odopen.desktop
ART=dock_icon.gif

help:
	@echo install: install *odmon*.  Binaries go into $(DESTDIR)
	@echo html: convert README.md into README.html
	@echo all: create artefacts: image files and README.html
	@echo clean: remove artefacts
	@echo mrproper: remove artefacts and backup files
	@echo req: list requisites

req:
	@echo html: markdown
	@echo dock_icon.gif: ImageMagick
	@echo dock_icon.xbm: ImageMagick

all:	$(ARTEFACTS)

install-bin: $(BINS)
	for f in $(BINS); do \
		cp $$f $(DESTDIR); \
		chmod +x $(DESTDIR)/$$f; \
	done

install-xdg: $(XDGS)
	for f in $(XDGS); do xdg-desktop-menu install $$f; done

install-art: $(ART)
	mkdir -p $(ICONDIR)
	for f in $(ART); do cp $$f $(ICONDIR); done

install: install-bin install-xdg install-art


uninstall-bin:
	-for f in $(BINS); do rm $(DESTDIR)/$$f; done

uninstall-xdg:
	-for f in $(XDGS); do xdg-desktop-menu uninstall $$f; done

uninstall-art:
	-for f in $(ART); do rm $(ICONDIR)/$$f; done

uninstall: uninstall-bin uninstall-xdg uninstall-art


html: README.html

clean:
	rm -rf $(ARTEFACTS)

mrproper: clean
	rm *~

%.html:	%.md
	markdown $< > $@

%.gif:	%.xcf
	convert $< $@

%.xbm:	%.xcf
	convert -negate $< $@

.PHONY: help html req clean mrproper \
	install install-bin install-xdg install-art \
	uninstall uninstall-bin uninstall-xdg uninstall-art
