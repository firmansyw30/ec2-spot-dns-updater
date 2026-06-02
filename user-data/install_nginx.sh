#!/bin/bash
# ============================================================
# Cross-Distro NGINX Installation Script
# Works on: Debian/Ubuntu, CentOS/RHEL, Fedora
# Author: Your Name
# ============================================================

set -e  # Exit on error

# --- Helper Functions ---
print_success() { echo -e "\e[32m$1\e[0m"; }
print_error()   { echo -e "\e[31m$1\e[0m"; }

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root. Try: sudo $0"
    exit 1
fi

# --- Detect Package Manager ---
if command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
else
    print_error "No supported package manager found (apt, dnf, yum)."
    exit 1
fi

print_success "Detected package manager: $PKG_MANAGER"

# --- Update & Install ---
case "$PKG_MANAGER" in
    apt)
        print_success "Updating package list..."
        apt update -y
        if ! command -v nginx >/dev/null 2>&1; then
            print_success "Installing NGINX..."
            apt install nginx -y
        else
            print_success "NGINX is already installed."
        fi
        ;;
    dnf)
        print_success "Updating package list..."
        dnf makecache
        if ! command -v nginx >/dev/null 2>&1; then
            print_success "Installing NGINX..."
            dnf install nginx -y
        else
            print_success "NGINX is already installed."
        fi
        ;;
    yum)
        print_success "Updating package list..."
        yum makecache fast
        if ! command -v nginx >/dev/null 2>&1; then
            print_success "Installing NGINX..."
            yum install epel-release -y
            yum install nginx -y
        else
            print_success "NGINX is already installed."
        fi
        ;;
esac

# --- Enable & Start Service ---
print_success "Enabling and starting NGINX..."
systemctl enable nginx
systemctl start nginx

# --- Verify Service ---
if systemctl is-active --quiet nginx; then
    print_success "✅ NGINX is running successfully!"
    print_success "Access it via: http://<your-server-ip>/"
else
    print_error "❌ NGINX failed to start. Check logs with: journalctl -xe"
    exit 1
fi
