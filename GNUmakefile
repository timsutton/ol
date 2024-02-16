export PATH := .:$(PATH)
$(shell mkdir -p config)
export OL_HOME=libraries

# detect external features
-include configure.mk

.PHONY: all debug release check slim config recompile install uninstall clean android
.PHONY: describe

all: release
describe: all
	./vm --version
	./ol --version
	echo "(print (syscall 63))"|./vm repl

# default toolchain(s)
CC ?= gcc
LD ?= ld

# win32 cross-compile
ol32.exe: CC := i686-w64-mingw32-gcc
ol64.exe: CC:=x86_64-w64-mingw32-gcc
ol.exe: CC := x86_64-w64-mingw32-gcc

# ansi colors
red=\033[1;31m
green=\033[1;32m
done=\033[0m

# check submodules
# ----------------
ifeq ($(shell ls -A libraries/OpenGL),)
    $(warning $(red)Submodules not loaded. Run 'git submodule update --init --recursive' once.$(done))
endif

# cleanup while insuccessfull builds
# ----------------------------------
$(shell [ -s tmp/repl.c ] || rm -rf tmp/repl.c)

# source code dependencies and flags
# ----------------------------------
include dependencies.mk

# autogenerations
# ----------------------------------

includes/ol/vm.h: src/olvm.c
	sed -e '/\/\/ <!--/,/\/\/ -->/d' $^ >$@

tmp/repl.c: repl
# vim
ifneq ($(shell which xxd),)
	echo "#include <stddef.h>" >tmp/repl.c
	xxd --include repl >>tmp/repl.c
else
# coreutils
ifneq ($(shell which od),)
	od -An -vtx1 repl| tr -d '\n'| sed \
	   -e 's/^ /0x/' -e 's/ /,0x/g' \
	   -e 's/^/unsigned char repl[] = {/' \
	   -e 's/$$/};/'> $@
else
	$(error "You must have 'od' (coreutils) or 'xxd' (vim) tool installed.")
endif
endif

# or
#	echo '(display "unsigned char repl[] = {") (lfor-each (lambda (x) (for-each display (list x ","))) (file->bytestream "repl")) (display "0};")'| ./vm repl> tmp/repl.c

doc/olvm.md: src/olvm.c extensions/ffi.c
	cat src/olvm.c extensions/ffi.c| tools/makedoc >doc/olvm.md

# compiler flags
# ----------------------------------
## os independent flags

CFLAGS += -std=gnu99 -fno-exceptions
CFLAGS += -DHAVE_SOCKETS=$(if $(HAVE_SOCKETS),$(HAVE_SOCKETS),0)
CFLAGS += -DHAVE_DLOPEN=$(if $(HAVE_DLOPEN),$(HAVE_DLOPEN),0)
CFLAGS += -DHAVE_SECCOMP=$(if $(HAVE_SECCOMP),$(HAVE_SECCOMP),0)

ifneq ($(HAS_MEMFD_CREATE),)
CFLAGS += -DHAS_MEMFD_CREATE=$(HAS_MEMFD_CREATE)
endif
ifneq ($(HAVE_SENDFILE),)
CFLAGS += -DHAVE_SENDFILE=$(HAVE_SENDFILE)
endif

# builtin "sin", "cos", "sqrt", etc. functions support
# can be disabled using "-DOLVM_BUILTIN_FMATH=0"
ifneq ($(OLVM_BUILTIN_FMATH),0)
   CFLAGS += -lm
#  CFLAGS += -ffast-math -mfpmath=387
else
   CFLAGS += -DOLVM_BUILTIN_FMATH=0
endif

# ----------------------------------
## debug/release flags
CFLAGS_CHECK   := -O0 -g2 -Wall -DWARN_ALL
CFLAGS_DEBUG   := -O0 -g2 -Wall
CFLAGS_DEBUG   += -DCAR_CHECK=1 -DCDR_CHECK=1
CFLAGS_RELEASE := $(if $(RPM_OPT_FLAGS), $(RPM_OPT_FLAGS), -O2 -DNDEBUG)

VERSION ?= $(shell echo `git describe --tags \`git rev-list --tags --max-count=1\``-`git rev-list HEAD --count`-`git log --pretty=format:'%h' -n 1`)

# ------------------------------------------------------
## os dependent flags

UNAME ?= $(shell uname -s)

# Linux
ifeq ($(UNAME),Linux)

ifeq ($(CC), tcc)
  L := $(if $(HAVE_DLOPEN), -ldl)
else
  L := $(if $(HAVE_DLOPEN), -ldl) \
       -Xlinker --export-dynamic
endif

# Debian i586 fix
ifeq ($(CC),gcc)
  CFLAGS += -I/usr/include/$(shell gcc -print-multiarch)
endif

endif #Linux

# BSD
ifeq ($(UNAME),FreeBSD)
  L := $(if $(HAVE_DLOPEN), -lc) \
       -Xlinker --export-dynamic

  LD := ld.bfd
endif
ifeq ($(UNAME),NetBSD)
  L := $(if $(HAVE_DLOPEN), -lc) \
       -Xlinker --export-dynamic
endif
ifeq ($(UNAME),OpenBSD)
  L := $(if $(HAVE_DLOPEN), -lc) \
       -Xlinker --export-dynamic
endif

ifeq ($(UNAME),Darwin)
  CFLAGS += -DSYSCALL_SYSINFO=0
  PREFIX ?= /usr/local
endif

# -----------------------------------------------
## 'clean/install' part
clean:
	rm -f boot.fasl
	rm -f ./vm ./ol ./olvm ./libol.so
	rm -r tmp/*

-include extras/setup.mk

# -----------------------------------------------
## builds

debug: CFLAGS += $(CFLAGS_DEBUG)
debug: vm ol olvm libol.so

release: CFLAGS += $(CFLAGS_RELEASE)
release: vm ol olvm libol.so

perf: CFLAGS += -O2 -g3 -DNDEBUG -Wall
perf: vm ol olvm libol.so


slim: CFLAGS += -DHAVE_SOCKETS=0 -DHAVE_DLOPEN=0 -DHAVE_SANDBOX=0
slim: release

minimal: CFLAGS += -DOLVM_FFI=0 -DHAVE_SOCKETS=0 -DHAVE_DLOPEN=0 -DHAVE_SANDBOX=0
minimal: release

# ffi test build
ffi: CFLAGS += $(CFLAGS_DEBUG)
ffi: src/olvm.c extensions/ffi.c tests/ffi.c
	$(CC) src/olvm.c -o $@ \
	   extensions/ffi.c -Iincludes \
	   tests/ffi.c \
	   $(CFLAGS) $(L)
	@echo Ok.
ffi32: CFLAGS += $(CFLAGS_DEBUG) -m32
ffi32: src/olvm.c extensions/ffi.c tests/ffi.c
	$(CC) src/olvm.c -o $@ \
	   extensions/ffi.c -Iincludes \
	   tests/ffi.c \
	   $(CFLAGS) $(L)
	@echo Ok.

## android build
NDK_ROOT ?=/opt/android/ndk
android: jni/*.c tmp/repl.c
	$(NDK_ROOT)/ndk-build

# ol
vm:
	$(CC) src/olvm.c -o $@ \
	   extensions/ffi.c -Iincludes \
	   $(CFLAGS) -DPREFIX=\"$(PREFIX)\" $(L)
	@echo Ok.
vm.asm:
	$(CC) src/olvm.c -o $@ \
	   -DHAVE_DLOPEN=0  -Iincludes \
	   $(CFLAGS_RELEASE) -DPREFIX=\"$(PREFIX)\" $(L) \
	   -S -fverbose-asm
	@echo Ok.

ol:
	$(CC) src/olvm.c -o $@ \
	   extensions/ffi.c -Iincludes \
	   $(CFLAGS) -DPREFIX=\"$(PREFIX)\" $(L) \
	   tmp/repl.c -DREPL=repl
	@echo Ok.

libol.so:
	$(CC) src/olvm.c -o $@ \
	   extensions/ffi.c -Iincludes \
	   $(CFLAGS) -DPREFIX=\"$(PREFIX)\" $(L) \
	   tmp/repl.c -DREPL=repl \
	   -DOLVM_NOMAIN -shared -fPIC
	@echo Ok.

# real name of
olvm: vm
	cp vm olvm

# selfexec feature test
selfexec: ol
	objcopy --add-section .lisp=selfexec.lisp \
	        --set-section-flags .lisp=noload,readonly $^ $@

# windows

# You can debug ol.exe using "winedbg --gdb ol.exe"
# require mingw-w64-i686-dev (+ gcc-mingw-w64-i686) or/and mingw-w64-x86-64-dev (+ gcc-mingw-w64-x86-64)
%.exe: MINGWCFLAGS += -std=gnu99 -fno-exceptions
%.exe: MINGWCFLAGS += -Wno-shift-count-overflow
%.exe: MINGWCFLAGS += $(CFLAGS_RELEASE)
%.exe: src/olvm.c extensions/ffi.c tmp/repl.c
	$(CC) \
	   $^ -o $@ \
	   -DREPL=repl \
	   -DHAVE_DLOPEN=1 -DHAS_SOCKES=1 -DOLVM_FFI=1 \
	   -Iincludes/win32 -Iincludes \
	   $(MINGWCFLAGS) -lws2_32

# compiling the Ol language
recompile: boot.fasl
boot.fasl: vm repl src/*.scm lang/*.scm libraries/otus/*.scm libraries/owl/*.scm libraries/scheme/*.scm
	@vm repl --version="$(VERSION)" --home=.:libraries \
	   src/ol.scm
	@if diff boot.fasl repl>/dev/null;then\
	   echo '$(green)  `___`  $(done)' ;\
	   echo '$(green)  (o,o)  $(done)' ;\
	   echo '$(green)  \)  )  $(done)' ;\
	   echo '$(green)___"_"___$(done)' ;\
	   echo '$(green)Build Ok.$(done)' ;\
	else \
	   echo `stat -c%s repl` -\> `stat -c%s $@` ;\
	   cp -b $@ repl ;$(MAKE) $@ ;\
	fi

# compiling infix math notation
libraries/owl/math/infix.scm: tools/make-math-infix.scm vm
	./vm repl tools/make-math-infix.scm >$@

# additional targets (like packaging, tests, etc.)
MAKEFILE_MAIN=1
-include extras/wasm.mk

-include tests/Makefile
-include tests/rosettacode/Makefile
-include config/Makefile

# documentation samples check
check: ol check-reference
check-reference: ol
check-reference: $(wildcard doc/reference/*.md)
	@echo "Testing reference samples:"
	@./ol tools/check-reference.lisp $(filter %.md,$^) && echo $(ok) || echo $(failed)
