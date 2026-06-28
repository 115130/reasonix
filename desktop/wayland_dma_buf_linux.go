//go:build linux

package main

import (
	"os"
)

// init applies a GDK backend workaround on Wayland when the WebKitGTK webview
// exhibits text-rendering issues (collapsed/crammed glyphs at fractional scale
// factors). This is a known issue with WebKitGTK's DMA-BUF rendering path on
// certain GPU/driver/compositor combinations (Intel/AMD with KDE Plasma
// Wayland), and the upstream fix has not been backported to the WebKit version
// shipped by many distros.
//
// Setting GDK_BACKEND=x11 forces the GTK/WebKit stack to run through XWayland
// instead of the native Wayland protocol. This completely sidesteps the DMA-BUF
// rendering path and resolves the text-cramming issue. The trade-off is:
//   - A thin XWayland translation layer (negligible overhead for a chat UI)
//   - Loss of pure-Wayland-only features (fractional-scaling VRR protocol, etc.)
//
// The original attempt using WEBKIT_DISABLE_DMABUF_RENDERER=1 (disabling DMA-BUF
// while staying on native Wayland) was insufficient for this GPU/compositor
// combination, so GDK_BACKEND=x11 is the proven workaround.
//
// The fix only applies when all three conditions are true:
//  1. Wayland session (WAYLAND_DISPLAY set or XDG_SESSION_TYPE=wayland)
//  2. No NVIDIA GPU present (nvidia_wayland_linux.go has its own fix)
//  3. User has not already explicitly set GDK_BACKEND
func init() {
	// Only apply under Wayland — this is a Wayland-specific rendering issue.
	if os.Getenv("WAYLAND_DISPLAY") == "" && os.Getenv("XDG_SESSION_TYPE") != "wayland" {
		return
	}
	// Skip NVIDIA — the existing explicit-sync workaround is a better fix that
	// preserves native Wayland with GPU acceleration.
	if nvidiaGPUDetected() {
		return
	}
	// Respect an explicit user choice so the workaround can be opted out of
	// (or forced on by pre-setting the env var).
	if _, ok := os.LookupEnv("GDK_BACKEND"); ok {
		return
	}
	os.Setenv("GDK_BACKEND", "x11")
}

// nvidiaGPUDetected checks whether the NVIDIA kernel module is loaded by looking
// for /sys/module/nvidia. This duplicates the check in nvidia_wayland_linux.go
// but lives in a separate file with its own build tag so the two workarounds
// remain independently composable.
func nvidiaGPUDetected() bool {
	_, err := os.Stat("/sys/module/nvidia")
	return err == nil
}
