//go:build linux

package main

import (
	"os"
	"path/filepath"
)

// init applies a WebKitGTK DMA-BUF workaround on Wayland for non-NVIDIA GPUs.
// On KDE Plasma / GNOME Wayland with Intel or AMD GPUs, WebKitGTK's DMA-BUF
// rendering path can cause text to render collapsed / crammed together at
// fractional scale factors (125 %, 150 %, etc.) because the buffer stride and
// text-glyph positioning disagree on the backing-store dimensions.
//
// Disabling DMA-BUF (WEBKIT_DISABLE_DMABUF_RENDERER=1) forces WebKitGTK to use
// a software-pixel shm (shared-memory) transport instead. This loses the GPU
// compositing fast path but eliminates the scaling mismatch — text metrics
// match the actual backing store exactly. Performance is adequate for a chat
// UI on any GPU made in the last decade.
//
// NVIDIA GPUs are excluded because the existing nvidia_wayland_linux.go
// workaround (__NV_DISABLE_EXPLICIT_SYNC=1) already fixes the problem while
// preserving GPU acceleration; piling DMA-BUF disable on top would only lose
// performance without benefit.
//
// The fix only applies when all three conditions are true:
//  1. Wayland session (WAYLAND_DISPLAY set or XDG_SESSION_TYPE=wayland)
//  2. No NVIDIA GPU present (so nvidia_wayland_linux.go does not apply)
//  3. User has not already explicitly set WEBKIT_DISABLE_DMABUF_RENDERER
func init() {
	// Only apply under Wayland — the DMA-BUF scaling issue is Wayland-specific.
	if os.Getenv("WAYLAND_DISPLAY") == "" && os.Getenv("XDG_SESSION_TYPE") != "wayland" {
		return
	}
	// Only skip NVIDIA — the existing explicit-sync workaround is a better fix.
	if nvidiaGPUDetected() {
		return
	}
	// Respect an explicit user choice so the workaround can be opted out of
	// (or forced on by pre-setting the env var).
	if _, ok := os.LookupEnv("WEBKIT_DISABLE_DMABUF_RENDERER"); ok {
		return
	}
	os.Setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1")
}

// nvidiaGPUDetected checks whether the NVIDIA kernel module is loaded by looking
// for /sys/module/nvidia. This duplicates the check in nvidia_wayland_linux.go
// but lives in a separate file with its own build tag so the two workarounds
// remain independently composable.
func nvidiaGPUDetected() bool {
	_, err := os.Stat(filepath.Join("/sys/module", "nvidia"))
	return err == nil
}
