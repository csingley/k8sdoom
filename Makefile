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

# --- Dependency Detection ---
FORCE_VENDORED ?= 0

ifeq ($(FORCE_VENDORED),0)
    SYS_SDL_CONFIG := $(shell command -v sdl-config 2>/dev/null)
    SYS_MIXER := $(shell pkg-config --exists SDL_mixer 2>/dev/null && echo yes)
    SYS_NET := $(shell pkg-config --exists SDL_net 2>/dev/null && echo yes)
endif

# Determine targets and variables
ifeq ($(SYS_SDL_CONFIG),)
    SDL_TARGET = $(VENDORED_PREFIX)/bin/sdl-config
    SDL_CONFIG = $(VENDORED_PREFIX)/bin/sdl-config
else
    SDL_TARGET = 
    SDL_CONFIG = $(SYS_SDL_CONFIG)
endif

ifeq ($(SYS_MIXER),)
    MIXER_TARGET = $(VENDORED_PREFIX)/lib/libSDL_mixer.a
else
    MIXER_TARGET = 
endif

ifeq ($(SYS_NET),)
    NET_TARGET = $(VENDORED_PREFIX)/lib/libSDL_net.a
else
    NET_TARGET = 
endif

# Environment for building missing dependencies
# We ONLY use these when building vendored stuff
VENDORED_ENV = PATH=$(VENDORED_PREFIX)/bin:$(PATH) \
               PKG_CONFIG_PATH=$(VENDORED_PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH) \
               LDFLAGS="-L$(VENDORED_PREFIX)/lib $(LDFLAGS)" \
               CPPFLAGS="-I$(VENDORED_PREFIX)/include $(CPPFLAGS)"

.PHONY: all build install uninstall clean check-tools

all: check-tools $(SDL_TARGET) $(MIXER_TARGET) $(NET_TARGET) build

check-tools:
	@command -v kubectl >/dev/null 2>&1 || (echo "ERROR: kubectl not found." && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "ERROR: jq not found." && exit 1)
	@command -v git >/dev/null 2>&1 || (echo "ERROR: git not found." && exit 1)
	@command -v curl >/dev/null 2>&1 || (echo "ERROR: curl not found." && exit 1)

# --- Vendored Dependency Targets ---

$(VENDORED_PREFIX)/bin/sdl-config: | $(BUILD_DIR)
	@echo "Building vendored SDL 1.2..."
	@mkdir -p $(VENDORED_PREFIX)
	@curl -L $(SDL_URL) | tar xz -C $(BUILD_DIR)
	@cd $(BUILD_DIR)/SDL-1.2.15 && ./configure --prefix=$(VENDORED_PREFIX) --disable-video-x11 && $(MAKE) install

$(VENDORED_PREFIX)/lib/libSDL_mixer.a: $(SDL_TARGET) | $(BUILD_DIR)
	@echo "Building vendored SDL_mixer..."
	@mkdir -p $(VENDORED_PREFIX)
	@curl -L $(SDL_MIXER_URL) | tar xz -C $(BUILD_DIR)
	@cd $(BUILD_DIR)/SDL_mixer-1.2.12 && $(VENDORED_ENV) ./configure --prefix=$(VENDORED_PREFIX) --with-sdl-prefix=$(VENDORED_PREFIX) && $(MAKE) install

$(VENDORED_PREFIX)/lib/libSDL_net.a: $(SDL_TARGET) | $(BUILD_DIR)
	@echo "Building vendored SDL_net..."
	@mkdir -p $(VENDORED_PREFIX)
	@curl -L $(SDL_NET_URL) | tar xz -C $(BUILD_DIR)
	@cd $(BUILD_DIR)/SDL_net-1.2.8 && $(VENDORED_ENV) ./configure --prefix=$(VENDORED_PREFIX) --with-sdl-prefix=$(VENDORED_PREFIX) && $(MAKE) install

# --- Main Build Target ---

build: $(BUILD_DIR)
	@if [ ! -d "$(BUILD_DIR)/psdoom-ng" ]; then \
		echo "Cloning psdoom-ng..."; \
		git clone $(PSDOOM_REPO) $(BUILD_DIR)/psdoom-ng; \
	fi
	@if [ ! -f "$(BUILD_DIR)/psdoom-ng/.patched" ]; then \
		echo "Applying Kubernetes patches..."; \
		cd $(BUILD_DIR)/psdoom-ng && patch -p1 < ../../patches/psdoom-k8s.patch && touch .patched; \
	fi
	@echo "Building psdoom-ng (SDL_CONFIG=$(SDL_CONFIG))..."
	@cd $(BUILD_DIR)/psdoom-ng/trunk && \
		$(VENDORED_ENV) ./configure --prefix=$(VENDORED_PREFIX) SDL_CONFIG=$(SDL_CONFIG) && \
		$(MAKE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# --- Assets ---

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
