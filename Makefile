# Linux QQ ChromeOS Fix (qq-crfix)
#
#   make
#   make install DESTDIR=... PREFIX=/usr
#
# LIBEXECDIR 下只放剪贴板注入库；启动脚本在安装时写入它的绝对路径。

NAME       := qq-crfix
VERSION    ?= $(or $(shell git describe --tags --always --dirty 2>/dev/null | sed 's/^v//'),0.0.0)

PREFIX     ?= /usr
BINDIR     ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/lib/$(NAME)
DATADIR    ?= $(PREFIX)/share
DOCDIR     ?= $(DATADIR)/doc/$(NAME)

CC         ?= cc
CFLAGS     ?= -O2 -g
PKG_CONFIG ?= pkg-config
WAYLAND_SCANNER ?= wayland-scanner

# 剪贴板修复：只需要 X11 与 wayland-client
CB_CFLAGS  := $(shell $(PKG_CONFIG) --cflags x11 wayland-client)
CB_LIBS    := $(shell $(PKG_CONFIG) --libs x11 wayland-client)

CB_LIB     := libqq-clipbridge.so
CMD        := $(NAME)
CB_PROTOCOLS := ext-data-control-v1 wlr-data-control-unstable-v1
CB_GEN_H   := $(CB_PROTOCOLS:%=build/%-client-protocol.h)
CB_GEN_C   := $(CB_PROTOCOLS:%=build/%-protocol.c)

all: $(CB_LIB) $(CMD)

build/%-client-protocol.h: protocol/%.xml
	@mkdir -p build
	$(WAYLAND_SCANNER) client-header $< $@

build/%-protocol.c: protocol/%.xml
	@mkdir -p build
	$(WAYLAND_SCANNER) private-code $< $@

CB_SRCS    := $(addprefix src/clipbridge/,main.c bridge.c x11.c wayland.c formats.c)

# 只导出拦截 QQ 调用的函数，内部函数不会与 QQ 的符号相撞
$(CB_LIB): $(CB_SRCS) src/clipbridge/clipbridge.h $(CB_GEN_H) $(CB_GEN_C)
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -fvisibility=hidden -Wall -Wextra -Ibuild $(CB_CFLAGS) \
	    $(LDFLAGS) -shared -Wl,-z,defs -o $@ $(CB_SRCS) $(CB_GEN_C) $(CB_LIBS) -lpthread -ldl

$(CMD): $(CMD).in
	sed -e 's|@LIBEXECDIR@|$(LIBEXECDIR)|g' -e 's|@VERSION@|$(VERSION)|g' $< > $@
	chmod +x $@

install: all
	install -Dm755 $(CB_LIB)         $(DESTDIR)$(LIBEXECDIR)/$(CB_LIB)
	install -Dm755 $(CMD)            $(DESTDIR)$(BINDIR)/$(CMD)
	install -Dm644 $(CMD).desktop    $(DESTDIR)$(DATADIR)/applications/$(CMD).desktop
	install -Dm644 README.md         $(DESTDIR)$(DOCDIR)/README.md
	for f in docs/*.md; do install -Dm644 "$$f" "$(DESTDIR)$(DOCDIR)/$$f"; done
	install -Dm644 LICENSE           $(DESTDIR)$(DATADIR)/licenses/$(NAME)/LICENSE

clean:
	rm -rf build src/*.o $(CB_LIB) $(CMD)

print-version:
	@echo $(VERSION)

.PHONY: all install clean print-version
