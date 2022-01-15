# luafar.mak

include ../config.mak

OUT= Out$(DIRBIT)
MYCFLAGS  = -DBUILD_DLL -DFAR_DONT_USE_INTERNALS -fvisibility=hidden
MYLDFLAGS = -llua5.1
LUAFARDLL = luafar2l.so

OBJ = \
  $(OUT)/farflags.o    \
  $(OUT)/farcolor.o    \
  $(OUT)/farkeys.o     \
  $(OUT)/bit.o         \
  $(OUT)/exported.o    \
  $(OUT)/lflua.o       \
  $(OUT)/lregex.o      \
  $(OUT)/service.o     \
  $(OUT)/slnunico.o    \
  $(OUT)/lutf8lib.o    \
  $(OUT)/ustring.o     \
  $(OUT)/util.o        \
  $(OUT)/reg.o         \
  $(OUT)/mytimer.o

$(OUT)/$(LUAFARDLL): $(OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)

$(OUT):
	mkdir -p $@

$(OUT)/%.o : %.c $(OUT)
	$(CC) $(CFLAGS) -c $< -o $@

# Dependencies
$(OUT)/*.o        : $(INC_FAR)/plugin.hpp
$(OUT)/reg.o      : reg.h
$(OUT)/service.o  : reg.h luafar.h util.h version.h ustring.h
$(OUT)/exported.o : luafar.h util.h ustring.h
$(OUT)/lregex.o   : luafar.h util.h ustring.h
$(OUT)/util.o     : util.h ustring.h
$(OUT)/lflua.o    : luafar.h util.h ustring.h
$(OUT)/luafar.o   : version.h

farflags.c: $(INC_FAR)/plugin.hpp
	$(LUAEXE) makeflags.lua '$<' > $@

farcolor.c: $(INC_FAR)/farcolor.hpp
	$(LUAEXE) makefarkeys.lua '$<' > $@

farkeys.c: $(INC_FAR)/farkeys.hpp
	$(LUAEXE) makefarkeys.lua '$<' > $@

# (end of Makefile)
