#!/bin/bash

echo "=========================================="
echo "Setting Up Development Workflow"
echo "=========================================="
echo ""

# Create development directory
DEV_DIR="$HOME/projects/dots-hyprland-dev"
echo "📁 Creating development directory: $DEV_DIR"
mkdir -p "$HOME/projects"

if [ -d "$DEV_DIR" ]; then
    echo "⚠️  Directory already exists. Remove it first? [y/N]"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DEV_DIR"
    else
        echo "Aborting."
        exit 1
    fi
fi

echo ""
read -p "Enter your GitHub username [tslove923]: " username
username=${username:-tslove923}

echo "📥 Cloning your fork to $DEV_DIR..."
git clone "https://github.com/${username}/dots-hyprland" "$DEV_DIR"

cd "$DEV_DIR" || exit 1

echo ""
echo "🔗 Adding upstream remote..."
git remote add upstream https://github.com/end-4/dots-hyprland
git remote -v

echo ""
echo "📋 Fetching all branches..."
git fetch --all

echo ""
echo "🌿 Setting up local tracking branches..."
git checkout feature/vpn-indicator
git checkout feature/copilot-integration  
git checkout feature/custom-keybinds
git checkout main

echo ""
echo "=========================================="
echo "✅ Development Setup Complete!"
echo "=========================================="
echo ""
echo "Your workflow:"
echo "  📂 Development: $DEV_DIR"
echo "  🔴 Live config: ~/.config"
echo "  💾 Cache repo:  ~/.cache/dots-hyprland"
echo ""
echo "Next: Create a test script to sync changes"

