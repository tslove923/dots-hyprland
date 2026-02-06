# Development Workflow

You're in the development repository: `~/projects/dots-hyprland-dev/`

## Quick Start

### Work on a Feature

```bash
# Switch to feature branch
git checkout feature/vpn-indicator

# Edit files
code dots/quickshell/ii/services/VpnStatus.qml

# Test changes in live config
bash /tmp/sync_and_test.sh vpn

# Commit changes
git add -A
git commit -m "feat: improve VPN detection"

# Push to your fork
git push origin feature/vpn-indicator
```

## Remotes

- **origin** → Your fork (https://github.com/tslove923/dots-hyprland)
- **upstream** → End-4's original (https://github.com/end-4/dots-hyprland)

## Key Commands

```bash
# See all branches
git branch -v

# Pull latest from end-4
git checkout main
git pull upstream main
git push origin main

# Update feature with latest main
git checkout feature/vpn-indicator
git rebase main

# Test changes
bash /tmp/sync_and_test.sh vpn
bash /tmp/sync_and_test.sh pull  # Pull changes back from live

# When pushing, always use origin (your fork)
git push origin $(git branch --show-current)
```

## Directory Structure

```
~/projects/dots-hyprland-dev/    ← You are here (dev workspace)
├── dots/                         ← Edit files here
├── README.md                     ← Changes per branch
└── .git/                         ← Git repository

~/.cache/dots-hyprland/          ← Original install location
└── .git/                         ← Git (can be used too)

~/.config/                        ← Live configuration
└── quickshell/ii/               ← Test changes here
```

## Pushing Rules

❌ **DON'T**: `git push origin feature/xxx` from cache repo  
   (origin = end-4's repo there)

✅ **DO**: `git push fork feature/xxx` from cache repo  
✅ **DO**: `git push origin feature/xxx` from dev repo

Or just work in dev repo to avoid confusion!
