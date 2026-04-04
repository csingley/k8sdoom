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

# Dependency URLs
SDL12_COMPAT_URL = https://github.com/libsdl-org/sdl12-compat/archive/refs/tags/release-1.2.68.tar.gz
SDL_MIXER_URL = https://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.12.tar.gz
SDL_NET_URL = https://www.libsdl.org/projects/SDL_net/release/SDL_net-1.2.8.tar.gz

# Build paths (Absolute)
CWD = $(CURDIR)
BUILD_DIR = $(CWD)/build_tmp
VENDORED_PREFIX = $(CWD)/build_tmp/deps_install
INSTALLED_DEPS_TRACKER = $(CWD)/.installed_deps

# Platform detection
UNAME_S := $(shell uname -s)

# --- Dependency Detection ---
FORCE_VENDORED ?= 0

ifeq ($(FORCE_VENDORED),0)
    SDL_VERSION := $(shell pkg-config --modversion sdl 2>/dev/null)
    MIXER_EXISTS := $(shell pkg-config --exists SDL_mixer 2>/dev/null && echo yes)
    NET_EXISTS := $(shell pkg-config --exists SDL_net 2>/dev/null && echo yes)
endif

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
V_CPPFLAGS = -I$(VENDORED_PREFIX)/include -I$(VENDORED_PREFIX)/include/SDL $(CPPFLAGS)
V_LD_PATH = $(VENDORED_PREFIX)/lib:$(LD_LIBRARY_PATH)
V_DYLD_PATH = $(VENDORED_PREFIX)/lib:$(DYLD_LIBRARY_PATH)

# execution wrapper for build steps
V_ENV = PATH="$(V_PATH)" \
        PKG_CONFIG_PATH="$(V_PKG_CONFIG_PATH)" \
        SDL_CONFIG="$(SDL_CONFIG)" \
        LD_LIBRARY_PATH="$(V_LD_PATH)" \
        DYLD_LIBRARY_PATH="$(V_DYLD_PATH)" \
        LDFLAGS="$(V_LDFLAGS)" \
        CPPFLAGS="$(V_CPPFLAGS)"

.PHONY: all build install uninstall clean check-tools deps-install deps-uninstall

all: deps-install $(SDL_DEP) $(MIXER_DEP) $(NET_DEP) build

# --- System Dependency Management ---

deps-install:
	@echo "Checking for system dependencies..."
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		command -v brew >/dev/null 2>&1 || (echo "Homebrew required for macOS auto-install." && exit 1); \
		if ! pkg-config --exists sdl2; then \
			echo "Installing SDL2 via Homebrew..."; \
			brew install sdl2 && echo "sdl2" >> "$(INSTALLED_DEPS_TRACKER)"; \
		fi; \
		if ! command -v cmake >/dev/null 2>&1; then \
			echo "Installing CMake via Homebrew..."; \
			brew install cmake && echo "cmake" >> "$(INSTALLED_DEPS_TRACKER)"; \
		fi; \
	elif [ "$(UNAME_S)" = "Linux" ]; then \
		if command -v apt-get >/dev/null 2>&1; then \
			if ! pkg-config --exists sdl2; then \
				echo "Installing libsdl2-dev via APT..."; \
				sudo apt-get update && sudo apt-get install -y libsdl2-dev && echo "libsdl2-dev" >> "$(INSTALLED_DEPS_TRACKER)"; \
			fi; \
			if ! command -v cmake >/dev/null 2>&1; then \
				echo "Installing cmake via APT..."; \
				sudo apt-get install -y cmake && echo "cmake" >> "$(INSTALLED_DEPS_TRACKER)"; \
			fi; \
		elif command -v pacman >/dev/null 2>&1; then \
			if ! pkg-config --exists sdl2; then \
				echo "Installing sdl2 via Pacman..."; \
				sudo pacman -S --noconfirm sdl2 && echo "sdl2" >> "$(INSTALLED_DEPS_TRACKER)"; \
			fi; \
			if ! command -v cmake >/dev/null 2>&1; then \
				echo "Installing cmake via Pacman..."; \
				sudo pacman -S --noconfirm cmake && echo "cmake" >> "$(INSTALLED_DEPS_TRACKER)"; \
			fi; \
		fi; \
	fi

deps-uninstall:
	@if [ -f "$(INSTALLED_DEPS_TRACKER)" ]; then \
		echo "Removing dependencies installed by k8sdoom..."; \
		while read p; do \
			if [ "$(UNAME_S)" = "Darwin" ]; then \
				brew uninstall $$p; \
			elif [ "$(UNAME_S)" = "Linux" ]; then \
				if command -v apt-get >/dev/null 2>&1; then sudo apt-get purge -y $$p; \
				elif command -v pacman >/dev/null 2>&1; then sudo pacman -Rs --noconfirm $$p; fi; \
			fi; \
		done < "$(INSTALLED_DEPS_TRACKER)"; \
		rm -f "$(INSTALLED_DEPS_TRACKER)"; \
	fi

check-tools:
	@command -v kubectl >/dev/null 2>&1 || (echo "ERROR: kubectl not found." && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "ERROR: jq not found." && exit 1)

# --- Vendored Dependencies ---

$(VENDORED_PREFIX)/bin/sdl-config:
	@echo "Building sdl12-compat..."
	@mkdir -p "$(BUILD_DIR)" "$(VENDORED_PREFIX)"
	@curl -L $(SDL12_COMPAT_URL) | tar xz -C "$(BUILD_DIR)"
	@cd "$(BUILD_DIR)"/sdl12-compat-* && \
		cmake -B build -DCMAKE_INSTALL_PREFIX="$(VENDORED_PREFIX)" -DSDL12COMPAT_STATIC=ON && \
		cmake --build build --target install

$(VENDORED_PREFIX)/lib/libSDL_mixer.a: $(SDL_DEP)
	@echo "Building SDL_mixer..."
	@mkdir -p "$(BUILD_DIR)" "$(VENDORED_PREFIX)"
	@curl -L $(SDL_MIXER_URL) | tar xz -C "$(BUILD_DIR)"
	@cd "$(BUILD_DIR)"/SDL_mixer-1.2.12 && \
		$(V_ENV) ./configure --prefix="$(VENDORED_PREFIX)" --with-sdl-prefix="$(VENDORED_PREFIX)" && \
		$(MAKE) install

$(VENDORED_PREFIX)/lib/libSDL_net.a: $(SDL_DEP)
	@echo "Building SDL_net..."
	@mkdir -p "$(BUILD_DIR)" "$(VENDORED_PREFIX)"
	@curl -L $(SDL_NET_URL) | tar xz -C "$(BUILD_DIR)"
	@cd "$(BUILD_DIR)"/SDL_net-1.2.8 && \
		$(V_ENV) ./configure --prefix="$(VENDORED_PREFIX)" --with-sdl-prefix="$(VENDORED_PREFIX)" && \
		$(MAKE) install

# --- Main Build ---

$(BUILD_DIR):
	@mkdir -p "$(BUILD_DIR)"

build: $(BUILD_DIR) $(SDL_DEP) $(MIXER_DEP) $(NET_DEP)
	@if [ ! -d "$(BUILD_DIR)/psdoom-ng" ]; then \
		git clone $(PSDOOM_REPO) "$(BUILD_DIR)/psdoom-ng"; \
	fi
	@if [ ! -f "$(BUILD_DIR)/psdoom-ng/.patched" ]; then \
		cd "$(BUILD_DIR)/psdoom-ng" && patch -p1 < ../../patches/psdoom-k8s.patch && touch .patched; \
	fi
	@echo "Building psdoom-ng..."
	@cd "$(BUILD_DIR)/psdoom-ng/trunk" && \
		$(V_ENV) ./configure --prefix="$(PREFIX)" \
		LIBS="-lSDL_mixer -lSDL_net" && \
		$(MAKE)

# --- Assets ---

$(WAD_NAME):
	@if [ ! -f "freedoom-0.13.0.zip" ]; then \
		curl -L $(FREEDOOM_URL) -o freedoom-0.13.0.zip; \
	fi
	@unzip -j freedoom-0.13.0.zip "freedoom-0.13.0/$(WAD_NAME)" -d .

install: build $(WAD_NAME)
	@mkdir -p "$(BINDIR)" "$(DATADIR)"
	@cp "$(BUILD_DIR)/psdoom-ng/trunk/src/psdoom-ng" "$(BINDIR)/psdoom-ng"
	@cp k8s-poll.sh "$(DATADIR)/k8s-poll.sh"
	@chmod +x "$(DATADIR)/k8s-poll.sh"
	@cp "$(WAD_NAME)" "$(DATADIR)/$(WAD_NAME)"
	@cp k8sdoom.sh "$(BINDIR)/k8sdoom"
	@chmod +x "$(BINDIR)/k8sdoom"
	@echo "Installation complete. Run 'k8sdoom' to start."

uninstall: deps-uninstall
	@echo "Removing k8sdoom binaries and assets..."
	rm -f "$(BINDIR)/psdoom-ng" "$(BINDIR)/k8sdoom"
	rm -rf "$(DATADIR)"

clean:
	rm -rf "$(BUILD_DIR)" freedoom-0.13.0.zip "$(WAD_NAME)"
