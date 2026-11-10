# xray-ui 伪装流量 + V2Ray 兼容版

这是一个面向实战场景的 Xray 面板增强版，专注于两点：

- V2Ray 兼容：兼容传统 V2Ray / v2-ui 配置习惯，降低迁移成本
- 伪装流量：支持把流量伪装成常见社交平台风格，例如 TikTok、微信、QQ、微博、百度等，提升遮蔽与混淆效果

本项目在原有 xray-ui 功能基础上，加入了默认兼容配置、低资源占用优化以及流量伪装能力，适合希望更稳定、更省资源、同时保留 V2Ray 用户习惯的部署场景。

## 项目特色

### 1. V2Ray 兼容模式

默认采用 V2Ray 兼容配置，适合以下用户：

- 习惯 v2ray / v2-ui / vmess 生态
- 需要快速迁移现有配置
- 希望保留原有面板使用习惯

默认兼容配置：

- `xrayCompatibilityProfile = v2ray`
- `xrayTrafficMask = mixed`

### 2. 伪装流量

支持多种流量伪装模式，可直接模拟常见平台的 HTTP 请求特征：

- `tiktok`
- `wechat`
- `qq`
- `weibo`
- `baidu`
- `mixed`

这些模式会在 Xray 配置生成时自动注入伪装头信息，增强流量“像正常社交应用流量”的效果。

### 3. 降低系统资源占用

本版默认进行了资源优化：

- 日志级别收敛到 warning
- 默认关闭冗余 metrics 输出
- 更适合低配 VPS / 小内存主机
- 配置生成时自动注入必要的兼容与统计项

### 4. 兼容 Windows 构建

已补充 Windows 下的系统调用实现，解决常见的构建失败问题，便于本地开发、调试和验证。

### 5. 适合一键安装

项目附带 Linux 安装脚本，开箱即可安装并初始化默认配置，减少手工配置步骤。

---

## 适用人群

- 需要兼容 V2Ray / v2-ui / vmess 的用户
- 想在 Xray 面板中保留常见社交平台流量特征的人
- 希望面板更稳、更轻、更容易部署的人
- 想要使用一键脚本快速安装的人

---

## 一键安装

Linux / VPS 一键安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/lingxistudio/xray-ui/main/install.sh)
```

如果你使用的是本地源码仓库，也可以直接：

```bash
git clone https://github.com/lingxistudio/xray-ui.git
cd xray-ui
```

---

## 默认行为说明

本版默认已启用：

- 兼容模式：`v2ray`
- 流量伪装：`mixed`
- 日志级别：`warning`
- 统计与 API 兼容项自动注入

也就是说，安装后无需额外配置，通常即能直接使用更接近 V2Ray 习惯的配置体验。

---

## 主要功能概览

- 支持多协议：vmess、vless、trojan、shadowsocks、dokodemo-door、socks、http
- 支持 web 面板管理
- 支持流量统计、限制流量、限制到期时间
- 支持自定义 Xray 模板
- 支持 HTTPS / 证书 / mTLS 配置
- 支持 geoip / geosite 更新
- 支持 REALITY / uTLS 相关场景
- 支持低资源运行与更稳健的默认策略

---

## 运行要求

- Linux VPS / 服务器
- root 权限
- 适当的安全组 / 防火墙配置
- 常见系统：Ubuntu / Debian / CentOS / Rocky / RedHat

---

## 说明

本项目基于上游 X-UI / Xray-UI 生态扩展，并加入了更实战化的兼容与伪装策略，目的是让它在保留传统 V2Ray 使用习惯的同时，也更适合资源受限、环境复杂、审查敏感的部署场景。

如果你想要更保守的纯 Xray 模式，也可以手动切换为 `xray` 兼容模式；如果你希望更偏“伪装流量”风格，则可切换为 `tiktok`、`wechat`、`qq`、`weibo`、`baidu` 或 `mixed`。

---

## 结论

本版的定位不是单纯“另一个 Xray 面板”，而是：

- 兼容 V2Ray 习惯
- 具备流量伪装能力
- 资源占用更低
- 更适合快速部署与长期稳定运行

这是一个更偏“实战、兼容、低资源、伪装流量”的 xray-ui 版本。        proxy_pass https://xray-ui;
        #proxy_pass_request_headers on;
        proxy_set_header Connection "keep-alive";
        proxy_store off;
    }
 }

后端mTLS 转发配置参考：
 upstream xray-ui {
        least_conn;
        server 127.0.0.1:54321 max_fails=3 fail_timeout=30s;
        keepalive 1000;
}
server {
    listen 443;
    server_name xray.test.com;
    client_max_body_size 0;
    chunked_transfer_encoding on;
    client_body_buffer_size 202400k;
    client_body_in_single_buffer on;
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options "DENY";
    add_header Alt-Svc 'h3=":443"; ma=86400, h3-29=":443"; ma=86400';
    ssl_certificate /apps/nginx/sslkey/test.com/fullchain.crt;
    ssl_certificate_key /apps/nginx/sslkey/test.com/private.key;
    ssl_buffer_size 4k;
    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers on;
    ssl_ecdh_curve X25519:P-256:P-384;
    client_header_timeout 24h;
    keepalive_timeout 24h;
    # 添加客户端证书和私钥路径
    ssl_client_certificate /apps/nginx/sslkey/test.com/fullchain.crt;
    ssl_certificate_key /apps/nginx/sslkey/test.com/private.key;

    # 如果需要指定 CA 证书
    # ssl_trusted_certificate /apps/nginx/sslkey/test.com/ca.crt;

    # 强制 SSL/TLS
    proxy_ssl_certificate /apps/nginx/sslkey/test.com/fullchain.crt;
    proxy_ssl_certificate_key /apps/nginx/sslkey/test.com/private.key;
    proxy_ssl_trusted_certificate /apps/nginx/sslkey/test.com/ca.crt;

    # 确保启用 TLS 验证
    proxy_ssl_verify on;
    proxy_ssl_verify_depth 2; # 可根据需要调整
    location / {
        proxy_redirect     off;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP   $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_ssl_session_reuse off;
        proxy_ssl_server_name on;
        proxy_buffering    off;
        proxy_ssl_name xray.test.com; #证书域名
        # 关闭对后端服务器自签名证书的验证
        proxy_ssl_verify off;
        proxy_connect_timeout      90;
        proxy_send_timeout         90;
        proxy_read_timeout         90;
        proxy_buffer_size          4k;
        proxy_buffers              4 32k;
        proxy_busy_buffers_size    64k;
        proxy_http_version 1.1;
        proxy_set_header Accept-Encoding "";
        proxy_pass https://xray-ui;
        #proxy_pass_request_headers on;
        proxy_set_header Connection "keep-alive";
        proxy_store off;
    }
 }
 # vpn代理nginx 配置参考
https://github.com/qist/xray/tree/main/xray/nginx
```
</details>

--------------------------------------------------------------------------------------------------------------------------------------------------

### 关于TG通知（上游内容）

<details>
  <summary>点击查看 关于TG通知</summary>

使用说明:在面板后台设置机器人相关参数

Tg机器人Token

Tg机器人ChatId

#### Tg机器人周期运行时间，采用crontab语法参考语法：

30 * * * * * //每一分的第30s进行通知

@hourly //每小时通知

@daily //每天通知（凌晨零点整）

@every 8h //每8小时通知

@every 30s  //每30s通知一次

#### TG通知内容：

节点流量使用

面板登录提醒

节点到期提醒

流量预警提醒

#### TG机器人可输入内容：

/delete port将会删除对应端口的节点

/restart 将会重启xray服务，该命令不会重启xray-ui面板自身

/status 将会获取当前系统状态

/enable port将会开启对应端口的节点

/disable port将会关闭对应端口的节点

/version 0.1.1.1 xray升级到1.6.0版本

/help 获取帮助信息

</details>

### Star

[![Star History Chart](https://star-history.dera.page/svg?repos=qist/xray-ui&type=Date)](https://star-history.dera.page/#qist/xray-ui&Date)