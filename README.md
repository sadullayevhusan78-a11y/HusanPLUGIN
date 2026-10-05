# Husan Reels Master

Minimal After Effects UXP panel for fast Reels workflows.

## Current features

- Create 1080×1920 / 30fps composition
- Center selected layers
- Fit selected layers to frame
- Add clean subtitle text
- Center text layers
- Apply minimal white text styling
- Stagger selected layers by 0.08s
- Apply a quick 0.18s fade-in

## Requirements

- Adobe After Effects 27.0 or newer
- UXP Developer Tool for loading the plugin during development

## Project structure

- manifest.json — UXP plugin manifest
- index.html — panel UI
- style.css — minimal dark UI
- main.js — After Effects automation

Adobe's current After Effects API exposes the host application through the UXP `aftereffects` module.