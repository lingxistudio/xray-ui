package xray

import (
	"encoding/json"
	"strings"
	"xray-ui/util/json_util"
)

type CompatibilityProfile string

const (
	CompatibilityXray  CompatibilityProfile = "xray"
	CompatibilityV2Ray CompatibilityProfile = "v2ray"
)

type TrafficMask string

const (
	TrafficMaskTikTok TrafficMask = "tiktok"
	TrafficMaskWeChat TrafficMask = "wechat"
	TrafficMaskQQ     TrafficMask = "qq"
	TrafficMaskWeibo  TrafficMask = "weibo"
	TrafficMaskBaidu  TrafficMask = "baidu"
	TrafficMaskMixed  TrafficMask = "mixed"
)

type CompatibilityOptions struct {
	Profile         CompatibilityProfile
	TrafficMask     TrafficMask
	EnableStats     bool
	EnableAPI       bool
	MemoryOptimized bool
}

func DefaultCompatibilityOptions() CompatibilityOptions {
	return CompatibilityOptions{
		Profile:         CompatibilityV2Ray,
		TrafficMask:     TrafficMaskMixed,
		EnableStats:     true,
		EnableAPI:       true,
		MemoryOptimized: true,
	}
}

func NormalizeCompatibilityProfile(raw string) CompatibilityProfile {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "v2ray", "v2ray-ui", "v2-ui", "v2", "vmess":
		return CompatibilityV2Ray
	default:
		return CompatibilityXray
	}
}

func ParseTrafficMask(raw string) TrafficMask {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "tiktok":
		return TrafficMaskTikTok
	case "wechat":
		return TrafficMaskWeChat
	case "qq":
		return TrafficMaskQQ
	case "weibo":
		return TrafficMaskWeibo
	case "baidu":
		return TrafficMaskBaidu
	case "mixed", "all", "":
		return TrafficMaskMixed
	default:
		return TrafficMaskMixed
	}
}

func (cfg *Config) ApplyCompatibilityOptions(opts CompatibilityOptions) {
	if cfg == nil {
		return
	}
	if opts.Profile == "" {
		opts.Profile = CompatibilityV2Ray
	}
	if opts.TrafficMask == "" {
		opts.TrafficMask = TrafficMaskMixed
	}
	if opts.EnableStats == false && opts.Profile == CompatibilityV2Ray {
		opts.EnableStats = true
	}
	if opts.EnableAPI == false && opts.Profile == CompatibilityV2Ray {
		opts.EnableAPI = true
	}
	if opts.MemoryOptimized == false && opts.Profile == CompatibilityV2Ray {
		opts.MemoryOptimized = true
	}

	if len(cfg.Stats) == 0 && opts.EnableStats {
		cfg.Stats = json_util.RawMessage(`{}`)
	}
	if len(cfg.API) == 0 && opts.EnableAPI {
		cfg.API = json_util.RawMessage(`{"services":["HandlerService","LoggerService","StatsService"],"tag":"api"}`)
	}
	if len(cfg.Policy) == 0 {
		cfg.Policy = json_util.RawMessage(`{"system":{"statsInboundDownlink":true,"statsInboundUplink":true,"statsOutboundDownlink":false,"statsOutboundUplink":false},"levels":{"0":{"statsUserDownlink":true,"statsUserUplink":true}}}`)
	}

	hasAPI := false
	for _, inbound := range cfg.InboundConfigs {
		if inbound.Tag == "api" {
			hasAPI = true
			break
		}
	}
	if !hasAPI && opts.EnableAPI {
		cfg.InboundConfigs = append(cfg.InboundConfigs, InboundConfig{
			Listen:         json_util.RawMessage(`"127.0.0.1"`),
			Port:           62789,
			Protocol:       "dokodemo-door",
			Settings:       json_util.RawMessage(`{"address":"127.0.0.1"}`),
			StreamSettings: json_util.RawMessage(`{}`),
			Tag:            "api",
			Sniffing:       json_util.RawMessage(`{"enabled":true,"destOverride":["http","tls"]}`),
		})
	}

	for i := range cfg.InboundConfigs {
		inbound := &cfg.InboundConfigs[i]
		if len(inbound.Sniffing) == 0 {
			inbound.Sniffing = json_util.RawMessage(`{"enabled":true,"destOverride":["http","tls","fakedns"]}`)
		}
		if len(inbound.StreamSettings) == 0 || string(inbound.StreamSettings) == "null" {
			inbound.StreamSettings = json_util.RawMessage(buildTrafficMaskStreamSettings(opts.TrafficMask))
		}
	}

	if opts.MemoryOptimized && len(cfg.LogConfig) == 0 {
		cfg.LogConfig = json_util.RawMessage(`{"access":"none","error":"none","loglevel":"warning"}`)
	}
}

func buildTrafficMaskStreamSettings(mask TrafficMask) string {
	hosts := trafficMaskHosts(mask)
	payload := map[string]any{
		"network":  "tcp",
		"security": "none",
		"tcpSettings": map[string]any{
			"header": map[string]any{
				"type": "http",
				"request": map[string]any{
					"version": []string{"1.1"},
					"method":  "GET",
					"path":    []string{"/"},
					"headers": map[string]any{
						"Host":             hosts,
						"User-Agent":       []string{"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"},
						"Accept":           []string{"*/*"},
						"Accept-Encoding":  []string{"gzip, deflate, br"},
						"Connection":       []string{"keep-alive"},
						"Cache-Control":    []string{"no-cache"},
						"X-Requested-With": []string{"XMLHttpRequest"},
					},
				},
			},
		},
	}
	data, _ := json.Marshal(payload)
	return string(data)
}

func trafficMaskHosts(mask TrafficMask) []string {
	switch mask {
	case TrafficMaskTikTok:
		return []string{"www.tiktok.com", "www.tiktokv.com", "v16m.tiktokcdn.com"}
	case TrafficMaskWeChat:
		return []string{"wx.qq.com", "mp.weixin.qq.com", "res.wx.qq.com"}
	case TrafficMaskQQ:
		return []string{"qq.com", "im.qq.com", "qzonestyle.gtimg.cn"}
	case TrafficMaskWeibo:
		return []string{"weibo.com", "weibo.cn", "m.weibo.cn"}
	case TrafficMaskBaidu:
		return []string{"www.baidu.com", "map.baidu.com", "www.baidupcs.com"}
	default:
		return []string{"www.tiktok.com", "wx.qq.com", "qq.com", "weibo.com", "www.baidu.com"}
	}
}
