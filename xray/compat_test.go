package xray

import (
	"strings"
	"testing"

	"xray-ui/util/json_util"
)

func TestNormalizeCompatibilityProfile(t *testing.T) {
	if got := NormalizeCompatibilityProfile("V2RAY"); got != CompatibilityV2Ray {
		t.Fatalf("expected V2Ray profile, got %q", got)
	}
	if got := NormalizeCompatibilityProfile("  xray  "); got != CompatibilityXray {
		t.Fatalf("expected Xray profile, got %q", got)
	}
}

func TestApplyCompatibilityOptionsSkipsAPIInbound(t *testing.T) {
	cfg := &Config{
		InboundConfigs: []InboundConfig{
			{
				Port:     62789,
				Protocol: "dokodemo-door",
				Tag:      "api",
			},
			{
				Port:           49334,
				Protocol:       "vmess",
				Tag:            "main",
				StreamSettings: json_util.RawMessage(`{"network":"tcp","security":"none","tcpSettings":{"header":{"type":"none"}}}`),
			},
		},
	}

	cfg.ApplyCompatibilityOptions(CompatibilityOptions{
		Profile:     CompatibilityV2Ray,
		TrafficMask: TrafficMaskMixed,
	})

	if got := string(cfg.InboundConfigs[0].StreamSettings); got != "" {
		t.Fatalf("api inbound must not receive traffic mask, got %s", got)
	}
	got := string(cfg.InboundConfigs[1].StreamSettings)
	if !strings.Contains(got, `"type":"http"`) {
		t.Fatalf("expected http mask merged into main inbound, got %s", got)
	}
	if strings.Contains(got, `"version":[`) {
		t.Fatalf("version must be a string (Xray 26.11+ rejects arrays), got %s", got)
	}
	if !strings.Contains(got, `"version":"1.1"`) {
		t.Fatalf("expected string version 1.1, got %s", got)
	}
}

func TestApplyCompatibilityOptionsSkipsSecuredInbound(t *testing.T) {
	cfg := &Config{
		InboundConfigs: []InboundConfig{{
			Port:           8443,
			Protocol:       "vless",
			Tag:            "tls-in",
			StreamSettings: json_util.RawMessage(`{"network":"tcp","security":"tls","tlsSettings":{}}`),
		}},
	}

	cfg.ApplyCompatibilityOptions(CompatibilityOptions{
		Profile:     CompatibilityV2Ray,
		TrafficMask: TrafficMaskTikTok,
	})

	got := string(cfg.InboundConfigs[0].StreamSettings)
	if strings.Contains(got, `"type":"http"`) {
		t.Fatalf("tls inbound must not receive plain http mask, got %s", got)
	}
}

func TestTrafficMaskNoneLeavesInboundUntouched(t *testing.T) {
	if got := DefaultCompatibilityOptions().TrafficMask; got != TrafficMaskNone {
		t.Fatalf("default mask must be none so share-link clients work, got %q", got)
	}
	if got := ParseTrafficMask(""); got != TrafficMaskNone {
		t.Fatalf("empty mask must parse to none, got %q", got)
	}

	cfg := &Config{
		InboundConfigs: []InboundConfig{{
			Port:           49334,
			Protocol:       "vmess",
			Tag:            "main",
			StreamSettings: json_util.RawMessage(`{"network":"tcp","security":"none","tcpSettings":{"header":{"type":"none"}}}`),
		}},
	}
	cfg.ApplyCompatibilityOptions(CompatibilityOptions{
		Profile:     CompatibilityV2Ray,
		TrafficMask: TrafficMaskNone,
	})

	got := string(cfg.InboundConfigs[0].StreamSettings)
	if strings.Contains(got, `"type":"http"`) {
		t.Fatalf("mask none must not inject http header, got %s", got)
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
