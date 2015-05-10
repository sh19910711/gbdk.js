# Generic GB Makefile
CC = lcc-gb -A -Wl-j -Wl-m
AS = lcc-gb -c
LD = $(CC) -o

LDFLAGS :=
LDFLAGS += 

SUBDIRS = 
BIN = metro
OBJS = ui.o font.o font_draw.o metro.o \
	timer.o timer_handler.o bjork.o \
	font_spect.o 

IMAGES = 

CFLAGS=
VER = 0.12

all: $(BIN)

ui.o: ui.c ui.h font.h
font.o: font.ms font.h
main.o: ui.h font.h

%.ms: %.png
	png_to_gb -a -o $@ $<

%.s: %.ms
	maccer -o $@ $<

$(BIN): $(OBJS) $(FONTS) $(IMAGES)
	$(LD) $(LDFLAGS) $(BIN).gb $(OBJS) $(IMAGES)

clean: 
#	for i in $(SUBDIRS); do $(MAKE) -C $$i clean; done
	rm -f $(BIN).gb $(OBJS) $(IMAGES) *~ *.map *.lst *.sym *.rel stub.ms

dist-src: clean
	cd ..; tar czf $(BIN)-$(VER).tar.gz $(BIN)

dist-bin: $(BIN)
	cd ..; tar czf $(BIN)-$(VER)_bin.tar.gz $(BIN)
