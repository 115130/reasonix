package agent

import (
	"testing"

	"reasonix/internal/provider"
)

// TestSystemPromptCacheInvalidatedOnSetSession verifies that SetSession
// invalidates the systemPromptCache so the next call to systemPrompt()
// returns the new session's system messages, not the cached old ones.
func TestSystemPromptCacheInvalidatedOnSetSession(t *testing.T) {
	a := &Agent{
		session: NewSession("You are prompt A."),
	}

	// Populate the cache.
	p1 := a.systemPrompt()
	if p1 != "You are prompt A." {
		t.Fatalf("first call: got %q, want %q", p1, "You are prompt A.")
	}
	if a.systemPromptCache != "You are prompt A." {
		t.Fatalf("cache should be populated after first call, got %q", a.systemPromptCache)
	}

	// Replace the session — this must invalidate the cache.
	a.SetSession(NewSession("You are prompt B."))

	// Without invalidation, this returns the old cached value.
	p2 := a.systemPrompt()
	if p2 != "You are prompt B." {
		t.Errorf("after SetSession: got %q, want %q — systemPromptCache not cleared (value=%q)",
			p2, "You are prompt B.", a.systemPromptCache)
	}
}

// TestSystemPromptCacheWorksWithMultiMessageSystemPrompt tests that when
// there are multiple system messages, the cache works correctly across SetSession.
func TestSystemPromptCacheWorksWithMultiMessageSystemPrompt(t *testing.T) {
	s1 := NewSession("")
	s1.Add(provider.Message{Role: provider.RoleSystem, Content: "System A part 1"})
	s1.Add(provider.Message{Role: provider.RoleSystem, Content: "System A part 2"})
	s1.Add(provider.Message{Role: provider.RoleUser, Content: "hello"})

	a := &Agent{session: s1}

	p1 := a.systemPrompt()
	want1 := "System A part 1\nSystem A part 2"
	if p1 != want1 {
		t.Fatalf("first call: got %q, want %q", p1, want1)
	}

	s2 := NewSession("")
	s2.Add(provider.Message{Role: provider.RoleSystem, Content: "System B part 1"})
	s2.Add(provider.Message{Role: provider.RoleSystem, Content: "System B part 2"})
	a.SetSession(s2)

	p2 := a.systemPrompt()
	want2 := "System B part 1\nSystem B part 2"
	if p2 != want2 {
		t.Errorf("after SetSession: got %q, want %q — systemPromptCache=%q",
			p2, want2, a.systemPromptCache)
	}
}
