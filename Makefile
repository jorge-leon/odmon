# GNU Makefile for odmon
#
# (c) Georg Lehner <jorge-odmon@at.anteris.net>
# Share and use it as you like, but don't blame me.

DESTDIR=/usr/local/bin
ICONDIR=/usr/local/share/odmon
DDAPPDIR=/usr/local/share/applications

ARTEFACTS=dock_icon.gif dock_icon.xbm README.html

help:
	@echo install: install odmon.tcl into $(DESTDIR)
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

install: odmon.tcl dock_icon.gif odmon.desktop
	cp $< $(DESTDIR)
	chmod +x $(DESTDIR)/$<
	mkdir -p $(ICONDIR)
	cp dock_icon.gif $(ICONDIR)
	mkdir -p $(DDAPPDIR)
	cp odmon.desktop $(DDAPPDIR)

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

.PHONY: help install html req clean mrproper
