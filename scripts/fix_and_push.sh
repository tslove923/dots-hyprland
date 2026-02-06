#!/bin/bash

echo "=========================================="
echo "Fixing Remote Setup and Pushing Branches"
echo "=========================================="
echo ""

# Step 1: Push from cache repo to YOUR fork (not end-4's)
echo "📤 Step 1: Pushing feature branches from cache to YOUR fork..."
cd ~/.cache/dots-hyprland

echo ""
echo "Current remotes in cache repo:"
git remote -v
echo ""

read -p "Push to YOUR fork? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Pushing feature/vpn-indicator..."
    git push fork feature/vpn-indicator
    
    echo "Pushing feature/copilot-integration..."
    git push fork feature/copilot-integration
    
    echo "Pushing feature/custom-keybinds..."
    git push fork feature/custom-keybinds
    
    echo "Pushing main branch..."
    git push fork main
    
    echo "✅ All branches pushed to your fork!"
else
    echo "Skipped pushing."
fi

# Step 2: Fetch and checkout branches in dev repo
echo ""
echo "📥 Step 2: Fetching branches in dev repo..."
cd ~/projects/dots-hyprland-dev

echo "Fetching from origin (your fork)..."
git fetch origin

echo ""
echo "Creating local tracking branches..."
git checkout -b feature/vpn-indicator origin/feature/vpn-indicator 2>/dev/null || git checkout feature/vpn-indicator
git checkout -b feature/copilot-integration origin/feature/copilot-integration 2>/dev/null || git checkout feature/copilot-integration
git checkout -b feature/custom-keybinds origin/feature/custom-keybinds 2>/dev/null || git checkout feature/custom-keybinds

git checkout main

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Available branches:"
git branch -v
echo ""
echo "Now you can:"
echo "  cd ~/projects/dots-hyprland-dev"
echo "  git checkout feature/vpn-indicator"
echo "  # Edit files..."
echo "  git push origin feature/vpn-indicator"

