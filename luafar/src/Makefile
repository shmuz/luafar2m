# Makefile

include ../../config.mak

OUT= Out$(DIRBIT)
MYCFLAGS  = -DBUILD_DLL -DFAR_DONT_USE_INTERNALS -fvisibility=hidden
MYLDFLAGS = -luuid
TARGET = ../../$(LUAFARDLL)

OBJ = \
  $(OUT)/farflags.o    \
  $(OUT)/farcolor.o    \
  $(OUT)/farkeys.o     \
  $(OUT)/exported.o    \
  $(OUT)/lregex.o      \
  $(OUT)/service.o     \
  $(OUT)/slnunico.o    \
  $(OUT)/lutf8lib.o    \
  $(OUT)/ustring.o     \
  $(OUT)/util.o        \
  $(OUT)/reg.o         \
  $(OUT)/mytimer.o     \
  $(OUT)/lusercontrol.o

ifneq ($(USE_LUAJIT),1)
  OBJ += $(OUT)/bit.o
endif

.PHONY: directories all
all: directories $(TARGET)
directories: $(OUT)

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)

$(OUT):
	mkdir -p $@

$(OUT)/%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

farflags.c: $(INC_FAR)/farplug-wide.h
	$(LUAEXE) makeflags.lua '$<' > $@

farcolor.c: $(INC_FAR)/farcolor.h
	$(LUAEXE) makefarkeys.lua '$<' > $@

farkeys.c: $(INC_FAR)/farkeys.h
	$(LUAEXE) makefarkeys.lua '$<' > $@

# Dependencies
$(OUT)/*.o        : $(INC_FAR)/farplug-wide.h
$(OUT)/reg.o      : reg.h
$(OUT)/service.o  : reg.h luafar.h util.h version.h ustring.h
$(OUT)/exported.o : luafar.h util.h ustring.h
$(OUT)/lregex.o   : luafar.h util.h ustring.h
$(OUT)/util.o     : util.h ustring.h
$(OUT)/lflua.o    : luafar.h util.h ustring.h
$(OUT)/luafar.o   : version.h

# (end of Makefile)
