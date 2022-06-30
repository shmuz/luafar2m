# Include path where lua.h, luaconf.h and lauxlib.h reside:
INCLUDES= -I/usr/include/lua5.1

CC= gcc
CCOPT= -O2
CCWARN= -Wall
SOCC= $(CC) -shared
SOCFLAGS= -fPIC $(CCOPT) $(CCWARN) $(INCLUDES) $(CFLAGS)
SOLDFLAGS= -fPIC $(LDFLAGS)
RM= rm -f

MODNAME= reader
MODSO= ../plug/$(MODNAME).so

all: $(MODSO)

$(MODNAME).o: $(MODNAME).c
	$(CC) $(SOCFLAGS) -c -o $@ $<

$(MODSO): $(MODNAME).o
	$(SOCC) $(SOLDFLAGS) -o $@ $<

clean:
	$(RM) *.o *.so *.obj *.lib *.exp *.dll *.manifest

.PHONY: all clean
