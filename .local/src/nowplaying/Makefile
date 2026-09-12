CC ?= clang
CFLAGS ?= -O2 -Wall
PKG_FLAGS := $(shell pkg-config --cflags --libs gio-2.0)
TARGET ?= ~/.local/bin/nowplaying

all:
	mkdir -p ~/.local/bin
	$(CC) $(CFLAGS) main.c $(PKG_FLAGS) -o $(TARGET)
	chmod +x $(TARGET)

clean:
	rm -f $(TARGET)
