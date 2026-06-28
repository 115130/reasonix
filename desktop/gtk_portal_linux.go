//go:build linux

package main

import (
	"os"
)

// init sets GTK_USE_PORTAL=1 on Wayland non-NVIDIA sessions so the native
// folder/file chooser dialog uses the KDE/GNOME portal (xdg-desktop-portal)
// instead of the GTK file chooser. The GTK dialog can crash under Wayland
// with certain compositor/theme combinations (KDE Plasma + WebKitGTK).
//
// This complements the existing GDK_BACKEND=x11 workaround (wayland_dma_buf_linux.go),
// which routes the webview through XWayland. Even under XWayland the GTK file
// chooser dialog path can trigger the same crash, so forcing the portal API
// is an independent layer of defense.
//
// The fix only applies when all three conditions are true:
//  1. Wayland session (WAYLAND_DISPLAY set or XDG_SESSION_TYPE=wayland)
//  2. No NVIDIA GPU present (nvidia_wayland_linux.go has its own fix)
//  3. User has not already explicitly set GTK_USE_PORTAL
func init() {
	if os.Getenv("WAYLAND_DISPLAY") == "" && os.Getenv("XDG_SESSION_TYPE") != "wayland" {
		return
	}
	if nvidiaGPUDetected() {
		return
	}
	if _, ok := os.LookupEnv("GTK_USE_PORTAL"); ok {
		return
	}
	os.Setenv("GTK_USE_PORTAL", "1")
}
