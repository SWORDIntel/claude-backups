# Makefile for CloudUnflare Enhanced
# Advanced DNS reconnaissance tool with OPSEC capabilities

CC = gcc
CFLAGS = -Wall -Wextra -O3 -std=c99 -D_GNU_SOURCE
LIBS = -lcurl -lssl -lcrypto -ljson-c -lpthread
TARGET = cloudunflare
SOURCES = cloudunflare.c dns_enhanced.c
HEADERS = dns_enhanced.h config.h

# Check for required libraries
CURL_EXISTS := $(shell pkg-config --exists libcurl && echo yes)
SSL_EXISTS := $(shell pkg-config --exists openssl && echo yes)
JSON_EXISTS := $(shell pkg-config --exists json-c && echo yes)

.PHONY: all clean install deps check

all: check $(TARGET)

$(TARGET): $(SOURCES) $(HEADERS)
	@echo "Compiling CloudUnflare Enhanced with DNS improvements..."
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCES) $(LIBS)
	@echo "Build completed successfully!"
	@echo "Enhanced features: DoQ/DoH/DoT, IP enrichment, CDN detection, dual-stack IPv6"
	@echo "Run with: ./$(TARGET)"

check:
	@echo "Checking dependencies..."
ifeq ($(CURL_EXISTS),yes)
	@echo "✓ libcurl found"
else
	@echo "✗ libcurl not found - install with: sudo apt-get install libcurl4-openssl-dev"
	@exit 1
endif
ifeq ($(SSL_EXISTS),yes)
	@echo "✓ OpenSSL found"
else
	@echo "✗ OpenSSL not found - install with: sudo apt-get install libssl-dev"
	@exit 1
endif
ifeq ($(JSON_EXISTS),yes)
	@echo "✓ json-c found"
else
	@echo "✗ json-c not found - install with: sudo apt-get install libjson-c-dev"
	@exit 1
endif
	@echo "✓ All dependencies satisfied"

deps:
	@echo "Installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y libcurl4-openssl-dev libssl-dev libjson-c-dev build-essential pkg-config

install: $(TARGET)
	@echo "Installing CloudUnflare Enhanced..."
	sudo cp $(TARGET) /usr/local/bin/
	sudo chmod +x /usr/local/bin/$(TARGET)
	@echo "Installation completed. Run with: cloudunflare"

clean:
	@echo "Cleaning build files..."
	rm -f $(TARGET) test_enhanced
	@echo "Clean completed"

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: $(TARGET)

# Static analysis
analyze:
	@echo "Running static analysis..."
	cppcheck --enable=all --std=c99 $(SOURCE)

# Security hardening flags
secure: CFLAGS += -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE
secure: LIBS += -pie
secure: $(TARGET)
	@echo "Security-hardened build completed"

# Test suite
test: test_enhanced
	@echo "Running enhanced DNS resolution test suite..."
	./test_enhanced

test_enhanced: test_enhanced.c $(SOURCES) $(HEADERS)
	@echo "Building enhanced DNS test suite..."
	$(CC) $(CFLAGS) -o test_enhanced test_enhanced.c dns_enhanced.c $(LIBS)

help:
	@echo "CloudUnflare Enhanced Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all     - Build the application (default)"
	@echo "  test    - Build and run test suite"
	@echo "  deps    - Install required dependencies"
	@echo "  check   - Check for required dependencies"
	@echo "  debug   - Build with debug symbols"
	@echo "  secure  - Build with security hardening"
	@echo "  analyze - Run static code analysis"
	@echo "  install - Install to /usr/local/bin"
	@echo "  clean   - Remove build files"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Enhanced DNS Features:"
	@echo "  • DoQ/DoH/DoT protocol support with intelligent fallback"
	@echo "  • Dual-stack IPv4/IPv6 resolution"
	@echo "  • IP enrichment with geolocation and ASN data"
	@echo "  • CDN detection and origin discovery"
	@echo "  • Rate limiting and OPSEC protections"
	@echo ""
	@echo "Usage examples:"
	@echo "  make deps    # Install dependencies"
	@echo "  make         # Build application"
	@echo "  make test    # Run test suite"
	@echo "  make secure  # Build with security features"
	@echo "  make install # Install system-wide"