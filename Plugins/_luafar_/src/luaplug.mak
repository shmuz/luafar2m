# luaplug.mak

ifdef SELFTEST
include ../config.mak
TARGET  = luaplug.so
endif

OBJ       = luaplug.o
MYCFLAGS  = $(EXPORTS) $(FARVERSION)
MYLDFLAGS =

vpath %.c $(PATH_LUAFARSRC)
vpath %.h $(PATH_LUAFARSRC)

$(TARGET): $(OBJ) $(LUAFARDLL)
	$(CC) -o $@ $^ $(LDFLAGS)

$(LUAFARDLL):
	cd $(PATH_LUAFARSRC) && $(MAKE) -f luafar.mak

luaplug.o: luaplug.c luafar.h
