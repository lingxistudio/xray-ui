package xray

import "testing"

func TestNormalizeCompatibilityProfile(t *testing.T) {
	if got := NormalizeCompatibilityProfile("V2RAY"); got != CompatibilityV2Ray {
		t.Fatalf("expected V2Ray profile, got %q", got)
	}
	if got := NormalizeCompatibilityProfile("  xray  "); got != CompatibilityXray {
		t.Fatalf("expected Xray profile, got %q", got)
	}
}

func TestApplyCompatibilityOptions(t *testing.T) {
	cfg := &Config{
		InboundConfigs: []InboundConfig{{
			Port:     443,
			Protocol: "vmess",
			Tag:      "main",
		}},
	}

	cfg.ApplyCompatibilityOptions(CompatibilityOptions{
		Profile:     CompatibilityV2Ray,
		TrafficMask: TrafficMaskTikTok,
	})

	if len(cfg.InboundConfigs) == 0 || cfg.InboundConfigs[0].StreamSettings == nil {
		t.Fatal("expected traffic mask to populate stream settings")
	}
	if string(cfg.Stats) == "" {
		t.Fatal("expected stats to be enabled for compatibility mode")
	}
	if string(cfg.API) == "" {
		t.Fatal("expected API config to be present")
	}
}
