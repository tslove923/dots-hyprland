# Makefile for AI Assistant Wake Word Detector

.PHONY: all build install clean test status

all: build

# Build the package
build:
	@echo "Building package..."
	makepkg -sf

# Build and install in one step
install:
	@echo "Building and installing package..."
	makepkg -sfi

# Clean build artifacts (keeps cache)
clean:
	@echo "Cleaning build artifacts..."
	rm -f *.pkg.tar.zst
	rm -rf pkg/ src/

# Clean everything including cache (forces full rebuild)
clean-all: clean
	@echo "Removing cached venv..."
	rm -rf .cached_venv_*

# Test the installed service
test:
	@echo "Testing wake word detector..."
	@if systemctl --user is-active --quiet ai-assistant-wake-word; then \
		echo "✅ Service is running"; \
	else \
		echo "❌ Service is not running"; \
		echo "Start with: systemctl --user start ai-assistant-wake-word"; \
	fi

# Check service status
status:
	systemctl --user status ai-assistant-wake-word

# View logs
logs:
	journalctl --user -u ai-assistant-wake-word -f

# Enable service
enable:
	systemctl --user enable ai-assistant-wake-word

# Start service
start:
	systemctl --user start ai-assistant-wake-word

# Stop service
stop:
	systemctl --user stop ai-assistant-wake-word

# Restart service
restart:
	systemctl --user restart ai-assistant-wake-word

# Uninstall
uninstall:
	systemctl --user stop ai-assistant-wake-word 2>/dev/null || true
	systemctl --user disable ai-assistant-wake-word 2>/dev/null || true
	sudo pacman -R ai-assistant-wake-word-npu

help:
	@echo "AI Assistant Wake Word Detector - Makefile targets:"
	@echo ""
	@echo "  make build       - Build package (keeps cache)"
	@echo "  make install     - Build and install package"
	@echo "  make clean       - Remove build artifacts (keeps cache)"
	@echo "  make clean-all   - Remove everything including cache"
	@echo "  make test        - Test if service is running"
	@echo "  make status      - Show service status"
	@echo "  make logs        - Show live logs"
	@echo "  make enable      - Enable service at boot"
	@echo "  make start       - Start service"
	@echo "  make stop        - Stop service"
	@echo "  make restart     - Restart service"
	@echo "  make uninstall   - Remove package and stop service"
