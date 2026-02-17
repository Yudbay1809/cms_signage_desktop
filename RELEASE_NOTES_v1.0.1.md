# Release Notes v1.0.1

## Date
2026-02-17

## Summary
Patch release for scheduler usability, device cache checking, and popup-noise reduction.

## What's New
- Flash Sale scheduler UX simplified to `HH:MM` flow with quick presets and time picker.
- Added `Cek Download Media` in Devices tab:
  - reads backend media cache status per selected device
  - shows `ready`, cache ratio, and missing media summary
- Notification popup behavior improved:
  - startup/background snackbar spam disabled by default
  - manual toggle provided (`Popup Notif: ON/OFF`)

## Notes
- Requires backend with media cache status endpoints for full device download-check functionality.

