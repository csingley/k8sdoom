# k8sdoom Makefile
# Modernized build system for Linux and Mac (aarch64 compatible)

# Install paths (Absolute)
export PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
DATADIR = $(PREFIX)/share/k8sdoom

# Source and Assets
PSDOOM_REPO = https://github.com/keymon/psdoom-ng.git
FREEDOOM_URL = https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip
WAD_NAME = freedoom2.wad

# Modern replacements for legacy SDL 1.2
SDL12_COMPAT_URL = https://github.com/libsdl-org/sdl12-compat/archive/refs/tags/release-1.2.68.tar.gz
SDL_MIXER_URL = https://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.12.tar.gz
SDL_NET_URL = https://www.libsdl.org/projects/SDL_net/release/SDL_net-1.2.8.tar.gz

# Build paths (Absolute)
CWD = $(shell pwd)
BUILD_DIR = $(CWD)/build_tmp
VENDORED_PREFIX = $(CWD)/build_tmp/deps_install

# --- Dependency Detection ---
FORCE_VENDORED ?= 0

ifeq ($(FORCE_VENDORED),0)
    # Check for modern SDL via pkg-config
    SDL_VERSION := $(shell pkg-config --modversion sdl 2>/dev/null)
    MIXER_EXISTS := $(shell pkg-config --exists SDL_mixer 2>/dev/null && echo yes)
    NET_EXISTS := $(shell pkg-config --exists SDL_net 2>/dev/null && echo yes)
endif

# If anything is missing, we use the vendored paths
ifeq ($(SDL_VERSION),)
    SDL_DEP = $(VENDORED_PREFIX)/bin/sdl-config
    SDL_CONFIG = $(VENDORED_PREFIX)/bin/sdl-config
else
    SDL_CONFIG = $(shell which sdl-config 2>/dev/null || echo "pkg-config sdl")
endif

ifeq ($(MIXER_EXISTS),)
    MIXER_DEP = $(VENDORED_PREFIX)/lib/libSDL_mixer.a
endif

ifeq ($(NET_EXISTS),)
    NET_DEP = $(VENDORED_PREFIX)/lib/libSDL_net.a
endif

# Build environment variables
V_PATH = $(VENDORED_PREFIX)/bin:$(PATH)
V_PKG_CONFIG_PATH = $(VENDORED_PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)
V_LDFLAGS = -L$(VENDORED_PREFIX)/lib $(LDFLAGS)
V_CPPFLAGS = -I$(VENDORED_PREFIX)/include $(CPPFLAGS)

.PHONY: all build install uninstall clean check-tools

all: check-tools $(SDL_DEP) $(MIXER_DEP) $(NET_DEP) build

check-tools:
	@command -v kubectl >/dev/null 2>&1 || (echo "ERROR: kubectl not found." && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "ERROR: jq not found." && exit 1)
	@command -v cmake >/dev/null 2>&1 || (echo "ERROR: cmake required." && exit 1)
	@pkg-config --exists sdl2 || (echo "ERROR: SDL2 is required to build sdl12-compat. Run 'brew install sdl2' or 'apt install libsdl2-dev'." && exit 1)

# --- Vendored Dependencies ---

$(VENDORED_PREFIX)/bin/sdl-config:
	@echo "Building sdl12-compat..."
	@mkdir -p $(BUILD_DIR) $(VENDORED_PREFIX)
	@curl -L $(SDL12_COMPAT_URL) | tar xz -C $(BUILD_DIR)
	@cd $(BUILD_DIR)/sdl12-compat-* && \
		cmake -B build -DCMAKE_INSTALL_PREFIX=$(VENDORED_PREFIX) -DSDL12COMPAT_STATIC=ON && \
		cmake --build build --target install
	@if [ ! -f "$@" ]; then echo "ERROR: sdl-config not produced at $@" && exit 1; fi

$(VENDORED_PREFIX)/lib/libSDL_mixer.a: $(SDL_DEP)
	@echo "Building SDL_mixer..."
	@curl -L $(SDL_MIXER_URL) | tar xz -C $(BUILD_DIR)
	@cd $(BUILD_DIR)/SDL_mixer-1.2.12 && \
		PATH="$(V_PATH)" \
		PKG_CONFIG_PATH="$(V_PKG_CONFIG_PATH)" \
		SDL_CONFIG="$(SDL_CONFIG)" \
		./configure --prefix=$(VENDORED_PREFIX) --with-sdl-prefix=$(VENDORED_PREFIX) \
		LDFLAGS="$(V_LDFLAGS)" CPPFLAGS="$(V_CPPFLAGS)" && \
		$(MAKE) install

$(VENDORED_PREFIX)/lib/libSDL_net.a: $(SDL_DEP)
	@echo "Building SDL_net..."
	@curl -L $(SDL_NET_URL) | tar xz -C $(BUILD_DIR)
	@cd $(BUILD_DIR)/SDL_net-1.2.8 && \
		PATH="$(V_PATH)" \
		PKG_CONFIG_PATH="$(V_PKG_CONFIG_PATH)" \
		SDL_CONFIG="$(SDL_CONFIG)" \
		./configure --prefix=$(VENDORED_PREFIX) --with-sdl-prefix=$(VENDORED_PREFIX) \
		LDFLAGS="$(V_LDFLAGS)" CPPFLAGS="$(V_CPPFLAGS)" && \
		$(MAKE) install

# --- Main Build ---

build: $(SDL_DEP) $(MIXER_DEP) $(NET_DEP)
	@if [ ! -d "$(BUILD_DIR)/psdoom-ng" ]; then \
		git clone $(PSDOOM_REPO) $(BUILD_DIR)/psdoom-ng; \
	fi
	@if [ ! -f "$(BUILD_DIR)/psdoom-ng/.patched" ]; then \
		cd $(BUILD_DIR)/psdoom-ng && patch -p1 < ../../patches/psdoom-k8s.patch && touch .patched; \
	fi
	@echo "Building psdoom-ng..."
	@cd $(BUILD_DIR)/psdoom-ng/trunk && \
		PATH="$(V_PATH)" \
		PKG_CONFIG_PATH="$(V_PKG_CONFIG_PATH)" \
		SDL_CONFIG="$(SDL_CONFIG)" \
		./configure --prefix=$(PREFIX) \
		LDFLAGS="$(V_LDFLAGS)" CPPFLAGS="$(V_CPPFLAGS)" \
		LIBS="-lSDL_mixer -lSDL_net" && \
		$(MAKE)

# --- Assets ---

$(WAD_NAME):
	@if [ ! -f "freedoom-0.13.0.zip" ]; then \
		curl -L $(FREEDOOM_URL) -o freedoom-0.13.0.zip; \
	fi
	@unzip -j freedoom-0.13.0.zip "freedoom-0.13.0/$(WAD_NAME)" -d .

install: build $(WAD_NAME)
	@mkdir -p $(BINDIR) $(DATADIR)
	@cp $(BUILD_DIR)/psdoom-ng/trunk/src/psdoom-ng $(BINDIR)/psdoom-ng
	@cp k8s-poll.sh $(DATADIR)/k8s-poll.sh
	@chmod +x $(DATADIR)/k8s-poll.sh
	@cp $(WAD_NAME) $(DATADIR)/$(WAD_NAME)
	@cp k8sdoom.sh $(BINDIR)/k8sdoom
	@chmod +x $(BINDIR)/k8sdoom
	@echo "Installation complete. Run 'k8sdoom' to start."

uninstall:
	rm -f $(BINDIR)/psdoom-ng $(BINDIR)/k8sdoom
	rm -rf $(DATADIR)

clean:
	rm -rf $(BUILD_DIR) freedoom-0.13.0.zip $(WAD_NAME)
