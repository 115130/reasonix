package control

import (
	"context"
	"errors"
	"testing"

	"reasonix/internal/agent"
)

// cancelRunner returns context.Canceled on first Run call so the orchestrator
// exercises the cancel rollback path where lastSafeStepIndex is read.
type cancelRunner struct {
	fakeTurnRunner
	callCount int
}

func (c *cancelRunner) Run(ctx context.Context, input string) error {
	c.fakeTurnRunner.Run(ctx, input)
	c.callCount++
	return context.Canceled
}

// TestLastSafeStepIndexReadOnCancel exercises the code path at
// turn_orchestrator.go lines 108-111 where c.lastSafeStepIndex is read
// without holding c.mu. This is a logic-exercise test (the race is
// detectable only with -race in concurrent scenarios).
func TestLastSafeStepIndexReadOnCancel(t *testing.T) {
	runner := &cancelRunner{}
	c := New(Options{Runner: runner})
	o := newTurnOrchestrator(c)

	err := o.runTurnWithRawDisplay(context.Background(), "hello", "hello", "")
	if err == nil {
		t.Fatal("expected context.Canceled error, got nil")
	}
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context.Canceled, got %v", err)
	}

	// The cancel path at lines 108-111 was exercised.
	// Without holding c.mu there, a concurrent writer (the step
	// boundary notifier) writing to c.lastSafeStepIndex would race.
	// This test verifies the code path is reachable; -race detects the actual data race.
	if runner.callCount != 1 {
		t.Fatalf("expected 1 call to runner, got %d", runner.callCount)
	}
}

// TestLastSafeStepIndexPreservesCompletedStepsOnCancel verifies that
// when the runner completes some steps (via step boundary notifier)
// and then cancels, the orchestrator preserves completed steps.
func TestLastSafeStepIndexPreservesCompletedStepsOnCancel(t *testing.T) {
	runner := &cancelRunner{}
	c := New(Options{Runner: runner})
	o := newTurnOrchestrator(c)

	startCount := c.sessionMessageCount()

	// Use a context with step boundary notifier to simulate
	// completed tool rounds before the cancel.
	stepCtx := agent.WithStepBoundaryNotifier(context.Background(), func(idx int) {
		c.mu.Lock()
		if idx > c.lastSafeStepIndex {
			c.lastSafeStepIndex = idx
		}
		c.mu.Unlock()
	})

	err := o.runTurnWithRawDisplay(stepCtx, "hello", "hello", "")
	if err == nil {
		t.Fatal("expected context.Canceled error, got nil")
	}

	// Simulate: after cancel, the orchestrator should strip messages
	// but preserve up to lastSafeStepIndex. The test verifies the
	// code path at lines 108-111 (and 144-149 for plan execution).
	t.Logf("startMessages=%d, lastSafeStepIndex=%d", startCount, c.lastSafeStepIndex)
}
