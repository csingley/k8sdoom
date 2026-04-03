# k8sdoom Makefile
# Portable, distro-agnostic build and install

# Install paths
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
DATADIR = $(PREFIX)/share/k8sdoom

# Source and Assets
PSDOOM_REPO = https://github.com/keymon/psdoom-ng.git
FREEDOOM_URL = https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip
WAD_NAME = freedoom2.wad

# Dependency URLs (SDL 1.2 legacy)
SDL_URL = https://www.libsdl.org/release/SDL-1.2.15.tar.gz
SDL_MIXER_URL = https://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.12.tar.gz
SDL_NET_URL = https://www.libsdl.org/projects/SDL_net/release/SDL_net-1.2.8.tar.gz

# Build paths
BUILD_DIR = $(shell pwd)/build_tmp
VENDORED_PREFIX = $(BUILD_DIR)/deps_install

# --- Dependency Detection Logic ---
FORCE_VENDORED ?= 0

ifeq ($(FORCE_VENDORED),0)
    # Check for SDL 1.2
    SYS_SDL_CONFIG := $(shell command -v sdl-config 2>/dev/null)
    # Check for Mixer and Net via pkg-config
    SYS_MIXER := $(shell pkg-config --exists SDL_mixer 2>/dev/null && echo yes)
    SYS_NET := $(shell pkg-config --exists SDL_net 2>/dev/null && echo yes)
endif

# Flags to track what needs building
NEED_VENDORED_SDL = 0
NEED_VENDORED_MIXER = 0
NEED_VENDORED_NET = 0

ifeq ($(SYS_SDL_CONFIG),)
    NEED_VENDORED_SDL = 1
endif
ifeq ($(SYS_MIXER),)
    NEED_VENDORED_MIXER = 1
endif
ifeq ($(SYS_NET),)
    NEED_VENDORED_NET = 1
endif

# If anything is missing, we might need vendor-deps
ifneq ($(NEED_VENDORED_SDL)$(NEED_VENDORED_MIXER)$(NEED_VENDORED_NET),000)
    VENDORED_TARGETS = vendor-deps
endif

# Paths for the build phase
# We add VENDORED_PREFIX to paths ALWAYS if we are in vendored mode, 
# but we must be careful not to break if it doesn't exist yet.
export PATH := $(VENDORED_PREFIX)/bin:$(PATH)
export PKG_CONFIG_PATH := $(VENDORED_PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)
export LDFLAGS := -L$(VENDORED_PREFIX)/lib $(LDFLAGS)
export CPPFLAGS := -I$(VENDORED_PREFIX)/include $(CPPFLAGS)

# Final SDL_CONFIG to use for psdoom-ng build
ifeq ($(NEED_VENDORED_SDL),1)
    SDL_CONFIG_CMD = $(VENDORED_PREFIX)/bin/sdl-config
else
    SDL_CONFIG_CMD = sdl-config
endif

.PHONY: all build install uninstall clean vendor-deps check-tools

all: check-tools $(VENDORED_TARGETS) build

check-tools:
	@command -v kubectl >/dev/null 2>&1 || (echo "ERROR: kubectl not found." && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "ERROR: jq not found." && exit 1)
	@command -v git >/dev/null 2>&1 || (echo "ERROR: git not found." && exit 1)
	@command -v curl >/dev/null 2>&1 || (echo "ERROR: curl not found." && exit 1)

# Target to build missing dependencies sequentially
vendor-deps: $(BUILD_DIR)
	@mkdir -p $(VENDORED_PREFIX)
	# 1. Build SDL 1.2 first (others depend on it)
	@if [ "$(NEED_VENDORED_SDL)" = "1" ] && [ ! -f "$(VENDORED_PREFIX)/bin/sdl-config" ]; then \
		echo "Building vendored SDL 1.2..."; \
		curl -L $(SDL_URL) | tar xz -C $(BUILD_DIR); \
		cd $(BUILD_DIR)/SDL-1.2.15 && ./configure --prefix=$(VENDORED_PREFIX) --disable-video-x11 && $(MAKE) install; \
	fi
	# 2. Build SDL_mixer
	@if [ "$(NEED_VENDORED_MIXER)" = "1" ] && [ ! -f "$(VENDORED_PREFIX)/lib/libSDL_mixer.a" ]; then \
		echo "Building vendored SDL_mixer..."; \
		curl -L $(SDL_MIXER_URL) | tar xz -C $(BUILD_DIR); \
		cd $(BUILD_DIR)/SDL_mixer-1.2.12 && ./configure --prefix=$(VENDORED_PREFIX) --with-sdl-prefix=$(VENDORED_PREFIX) && $(MAKE) install; \
	fi
	# 3. Build SDL_net
	@if [ "$(NEED_VENDORED_NET)" = "1" ] && [ ! -f "$(VENDORED_PREFIX)/lib/libSDL_net.a" ]; then \
		echo "Building vendored SDL_net..."; \
		curl -L $(SDL_NET_URL) | tar xz -C $(BUILD_DIR); \
		cd $(BUILD_DIR)/SDL_net-1.2.8 && ./configure --prefix=$(VENDORED_PREFIX) --with-sdl-prefix=$(VENDORED_PREFIX) && $(MAKE) install; \
	fi

build: $(BUILD_DIR)
	@if [ ! -d "$(BUILD_DIR)/psdoom-ng" ]; then \
		echo "Cloning psdoom-ng..."; \
		git clone $(PSDOOM_REPO) $(BUILD_DIR)/psdoom-ng; \
	fi
	@if [ ! -f "$(BUILD_DIR)/psdoom-ng/.patched" ]; then \
		echo "Applying Kubernetes patches..."; \
		cd $(BUILD_DIR)/psdoom-ng && patch -p1 < ../../patches/psdoom-k8s.patch && touch .patched; \
	fi
	@echo "Building psdoom-ng (SDL_CONFIG=$(SDL_CONFIG_CMD))..."
	@cd $(BUILD_DIR)/psdoom-ng/trunk && \
		./configure --prefix=$(VENDORED_PREFIX) SDL_CONFIG=$(SDL_CONFIG_CMD) && \
		$(MAKE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Fetch assets
$(WAD_NAME):
	@if [ ! -f "freedoom-0.13.0.zip" ]; then \
		echo "Downloading Freedoom assets..."; \
		curl -L $(FREEDOOM_URL) -o freedoom-0.13.0.zip; \
	fi
	@unzip -j freedoom-0.13.0.zip "freedoom-0.13.0/$(WAD_NAME)" -d .

install: build $(WAD_NAME)
	@echo "Installing to $(PREFIX)..."
	@mkdir -p $(BINDIR)
	@mkdir -p $(DATADIR)
	@cp $(BUILD_DIR)/psdoom-ng/trunk/src/psdoom-ng $(BINDIR)/psdoom-ng
	@cp k8s-poll.sh $(DATADIR)/k8s-poll.sh
	@chmod +x $(DATADIR)/k8s-poll.sh
	@cp $(WAD_NAME) $(DATADIR)/$(WAD_NAME)
	@cp k8sdoom.sh $(BINDIR)/k8sdoom
	@chmod +x $(BINDIR)/k8sdoom
	@echo "Installation complete. Run 'k8sdoom' to start."

uninstall:
	@echo "Uninstalling k8sdoom..."
	rm -f $(BINDIR)/psdoom-ng
	rm -f $(BINDIR)/k8sdoom
	rm -rf $(DATADIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(WAD_NAME) freedoom-0.13.0.zip
