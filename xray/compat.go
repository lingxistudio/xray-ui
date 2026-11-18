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
	TrafficMaskNone  TrafficMask = "none"
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
		TrafficMask:     TrafficMaskNone,
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
	case "mixed", "all":
		return TrafficMaskMixed
	case "none", "off", "false", "":
		return TrafficMaskNone
	default:
		// 未知值一律不伪装，避免分享链接客户端握手失败
		return TrafficMaskNone
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
		opts.TrafficMask = TrafficMaskNone
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
		// 统计 API 入站仅监听回环，不参与流量伪装，否则会导致内核配置加载失败
		if inbound.Tag == "api" || inbound.Protocol == "dokodemo-door" {
			continue
		}
		if len(inbound.Sniffing) == 0 {
			inbound.Sniffing = json_util.RawMessage(`{"enabled":true,"destOverride":["http","tls","fakedns"]}`)
		}
		if merged, ok := mergeTrafficMaskStreamSettings(inbound.StreamSettings, opts.TrafficMask); ok {
			inbound.StreamSettings = merged
		}
	}

	if opts.MemoryOptimized && len(cfg.LogConfig) == 0 {
		cfg.LogConfig = json_util.RawMessage(`{"access":"none","error":"none","loglevel":"warning"}`)
	}
}

// buildTrafficMaskTCPSettings 生成伪装成常见站点 HTTP 请求的 tcpSettings。
// 注意：Xray 26.11+ 的 header.request.version 只接受字符串，数组会导致配置加载失败。
func buildTrafficMaskTCPSettings(mask TrafficMask) map[string]any {
	hosts := trafficMaskHosts(mask)
	return map[string]any{
		"header": map[string]any{
			"type": "http",
			"request": map[string]any{
				"version": "1.1",
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
	}
}

// mergeTrafficMaskStreamSettings 将伪装头合并进现有 streamSettings。
// 仅对未加密的 TCP 入站生效（security 为空/none 且 network 为 tcp），
// TLS/Reality/WS/gRPC/QUIC 等入站保持原样。返回 ok=false 表示不适用。
func mergeTrafficMaskStreamSettings(existing json_util.RawMessage, mask TrafficMask) (json_util.RawMessage, bool) {
	if mask == TrafficMaskNone {
		// 分享链接无法携带伪装头配置，服务端单方面伪装会导致普通客户端握手失败
		return existing, false
	}
	text := strings.TrimSpace(string(existing))
	if text == "" || text == "null" {
		text = "{}"
	}
	streamSettings := map[string]any{}
	if err := json.Unmarshal([]byte(text), &streamSettings); err != nil {
		return existing, false
	}
	security, _ := streamSettings["security"].(string)
	if security != "" && security != "none" {
		return existing, false
	}
	network, _ := streamSettings["network"].(string)
	if network == "" {
		network = "tcp"
		streamSettings["network"] = network
	}
	if network != "tcp" {
		return existing, false
	}
	streamSettings["tcpSettings"] = buildTrafficMaskTCPSettings(mask)
	data, err := json.Marshal(streamSettings)
	if err != nil {
		return existing, false
	}
	return json_util.RawMessage(data), true
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
