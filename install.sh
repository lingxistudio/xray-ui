#!/bin/bash
REPO_OWNER="lingxistudio"
REPO_NAME="xray-ui"
REPO_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}"
GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
bblue='\033[0;34m'
plain='\033[0m'

resolve_release_source() {
    local candidate_owners=("lingxistudio" "qist")
    local owner
    for owner in "${candidate_owners[@]}"; do
        local api_url="https://api.github.com/repos/${owner}/${REPO_NAME}/releases/latest"
        local tag
        tag=$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "${api_url}" 2>/dev/null \
            | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
            | head -n 1 \
            | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
        if [[ -n "${tag}" ]]; then
            REPO_OWNER="${owner}"
            REPO_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}"
            GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
            releases_version="${tag}"
            return 0
        fi
    done
    return 1
}

resolve_release_source || { echo -e "${red}无法获取 GitHub 最新发布版本，请确认仓库可访问并且已发布 release。${plain}"; exit 1; }

red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
blue() { echo -e "\033[36m\033[01m$1\033[0m"; }
white() { echo -e "\033[37m\033[01m$1\033[0m"; }
readp() { read -p "$(yellow "$1")" $2; }
remoteV=${releases_version}
clear
white "Github项目  ：${REPO_BASE}"
yellow "感谢xray-ui代码贡献者们（vaxilu）"
green "当前安装版本： $remoteV"
yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
sleep 2
cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os

if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /etc/system-release-cpe | grep -Eqi "amazon_linux"; then
    release="amazon_linux"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "arch: $(arch)"

sys() {
    [ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
    [ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
    [ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
}
op=$(sys)
version=$(uname -r | awk -F "-" '{print $1}')
vi=$(systemd-detect-virt)
white "VPS操作系统: $(blue "$op") \c" && white " 内核版本: $(blue "$version") \c" && white " CPU架构 : $(blue "$arch") \c" && white " 虚拟化类型: $(blue "$vi")"
sleep 2

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"amazon_linux" ]]; then
    if [[ ${os_version} -lt 2 ]]; then
        echo -e "${red}请使用 Amazon Linux 2 或更高版本的系统！${plain}\n" && exit 1
    fi
fi
ports=$(/usr/local/xray-ui/xray-ui 2>&1 | grep tcp | awk '{print $5}' | sed "s/://g")
if [[ -n $ports ]]; then
    green "经检测，xray-ui已安装"
    echo
    acp=$(/usr/local/xray-ui/xray-ui setting -show 2>/dev/null)
    green "$acp"
    echo
    readp "是否直接重装xray-ui，请输入Y/y键并回车。如不重装，输入N/n键回车退出脚本):" ins
    if [[ $ins = [Yy] ]]; then
        systemctl stop xray-ui
        systemctl disable xray-ui
        rm /etc/systemd/system/xray-ui.service -f
        systemctl daemon-reload
        systemctl reset-failed
        rm /etc/xray-ui/ -rf
        rm /usr/local/xray-ui/ -rf
        rm -rf /root/rayuil.sh /root/acme.sh
        sed -i '/xrayuil.sh/d' /etc/crontab
        sed -i '/xray-ui restart/d' /etc/crontab
    else
        exit 1
    fi
fi
install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        if [[ ${os_version} =~ 8 ]]; then
            yum clean all && yum makecache
        fi
        yum install epel-release -y && yum install wget curl tar gzip lsof sqlite -y

        setenforce 0 >/dev/null 2>&1
    else
        apt update && apt install wget curl tar lsof gzip sqlite3 -y
    fi
}
generate_random_string() {
    local n=$1
    # 定义数字、大写字母和小写字母的集合
    local characters='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

    # 生成随机字符并限制在指定字符集中
    # 从 /dev/urandom 生成随机字节，使用 tr 进行过滤
    local random_string=$(cat /dev/urandom | tr -dc "$characters" | fold -w "$n" | head -n 1)

    echo "$random_string"
}

ensure_default_compatibility_settings() {
    local db_path="/etc/xray-ui/xray-ui.db"
    if [[ ! -f "${db_path}" ]]; then
        yellow "xray-ui 数据库尚未初始化，跳过兼容配置写入"
        return 0
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        yellow "sqlite3 未安装，跳过兼容配置写入"
        return 0
    fi

    sqlite3 "${db_path}" "
        INSERT INTO settings (key, value) VALUES ('xrayCompatibilityProfile','v2ray')
        ON CONFLICT(key) DO UPDATE SET value='v2ray';
        INSERT INTO settings (key, value) VALUES ('xrayTrafficMask','none')
        ON CONFLICT(key) DO UPDATE SET value='none';
    " 2>/dev/null || true

    green "已设置默认兼容模式：V2Ray（默认不启用流量伪装，保证分享链接可用）"
}

# nginx 一键反代：把面板通过 HTTPS 暴露到外网
# 可用环境变量覆盖：
#   NGINX_PROXY=1        免交互直接执行（=0 则跳过）
#   NGINX_HTTP_PORT      跳转端口，默认 8080
#   NGINX_HTTPS_PORT     HTTPS 端口，默认 8443（避开 xray 常用 443）
#   NGINX_SERVER_NAME    证书 CN，默认取公网 IP
nginx_proxy() {
    local http_port="${NGINX_HTTP_PORT:-8080}"
    local https_port="${NGINX_HTTPS_PORT:-8443}"
    local server_name="${NGINX_SERVER_NAME:-}"
    local db_path="/etc/xray-ui/xray-ui.db"
    local cert_dir="/etc/nginx/ssl"
    local cert="${cert_dir}/panel.crt"
    local key="${cert_dir}/panel.key"
    local conf_file=""
    local panel_port=""
    local panel_path=""
    local panel_listen=""
    local upstream="127.0.0.1"
    local pub_ip=""

    if [[ x"${NGINX_PROXY}" == x"0" ]]; then
        yellow "已跳过 nginx 反代配置（NGINX_PROXY=0）"
        return 0
    fi
    if [[ x"${NGINX_PROXY}" != x"1" ]]; then
        read -p "$(yellow "是否用 nginx 一键把面板暴露到外网(HTTPS)？输入Y/y执行，N/n跳过: ")" npx
        if [[ ! $npx = [Yy] ]]; then
            yellow "已跳过 nginx 反代配置"
            return 0
        fi
    fi

    # ---------- 读取面板端口 / 路径 / 监听地址 ----------
    if command -v sqlite3 >/dev/null 2>&1 && [[ -f "${db_path}" ]]; then
        panel_port=$(sqlite3 "${db_path}" "SELECT value FROM settings WHERE key='webPort' LIMIT 1;" 2>/dev/null)
        panel_path=$(sqlite3 "${db_path}" "SELECT value FROM settings WHERE key='webBasePath' LIMIT 1;" 2>/dev/null)
        panel_listen=$(sqlite3 "${db_path}" "SELECT value FROM settings WHERE key='webListen' LIMIT 1;" 2>/dev/null)
    fi
    [[ -z "${panel_port}" ]] && panel_port=$(/usr/local/xray-ui/xray-ui 2>&1 | grep tcp | awk '{print $5}' | sed 's/://g')
    if [[ -z "${panel_port}" ]]; then
        echo -e "${red}无法获取面板端口，跳过 nginx 反代配置${plain}"
        return 1
    fi
    [[ -z "${panel_path}" ]] && panel_path="/"
    panel_path="${panel_path#/}"
    panel_path="${panel_path%/}"

    case "${panel_listen}" in
    "" | "0.0.0.0" | "::") upstream="127.0.0.1" ;;
    *) upstream="${panel_listen}" ;;
    esac

    # ---------- 安装 nginx ----------
    if ! command -v nginx >/dev/null 2>&1; then
        green "正在安装 nginx ..."
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y nginx
        elif command -v yum >/dev/null 2>&1; then
            yum install -y nginx
        elif command -v apt >/dev/null 2>&1; then
            apt update -qq >/dev/null 2>&1
            DEBIAN_FRONTEND=noninteractive apt install -y nginx >/dev/null 2>&1
        fi
    fi
    if ! command -v nginx >/dev/null 2>&1; then
        echo -e "${red}nginx 安装失败，跳过 nginx 反代配置${plain}"
        return 1
    fi

    # ---------- 端口占用检测（避免与 xray 等已占用端口冲突） ----------
    _port_in_use() { ss -tln 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$1\$"; }
    _owned_by_nginx() { ss -tlnp 2>/dev/null | grep -E "[:.]$1[[:space:]]" | grep -q nginx; }
    _pick_port() {
        local p=$1 n=0
        while _port_in_use "$p" && ! _owned_by_nginx "$p"; do
            p=$((p + 1))
            n=$((n + 1))
            if [[ $n -ge 50 ]]; then
                return 1
            fi
        done
        echo "$p"
    }
    local new_http new_https
    new_http=$(_pick_port "${http_port}")
    if [[ -z "${new_http}" ]]; then
        echo -e "${red}找不到空闲的 HTTP 反代端口，跳过${plain}"
        return 1
    fi
    new_https=$(_pick_port "${https_port}")
    if [[ -z "${new_https}" ]]; then
        echo -e "${red}找不到空闲的 HTTPS 反代端口，跳过${plain}"
        return 1
    fi
    if [[ "${new_http}" != "${http_port}" || "${new_https}" != "${https_port}" ]]; then
        yellow "端口 ${http_port}/${https_port} 已被占用，自动改用 ${new_http}/${new_https}"
    fi
    http_port="${new_http}"
    https_port="${new_https}"

    # ---------- 自签名证书 ----------
    mkdir -p "${cert_dir}"
    if [[ ! -f "${cert}" || ! -f "${key}" ]]; then
        local cn="${server_name}"
        if [[ -z "${cn}" ]]; then
            pub_ip=$(curl -s4m8 https://api.ipify.org 2>/dev/null || curl -s4m8 http://ip.sb -k 2>/dev/null || true)
            cn="${pub_ip:-xray-ui}"
        fi
        openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
            -keyout "${key}" -out "${cert}" \
            -subj "/CN=${cn}/O=xray-ui-panel" >/dev/null 2>&1
        chmod 600 "${key}"
        green "已生成自签名证书：${cert}（有效期 3650 天）"
    fi

    # ---------- 写入 nginx 配置 ----------
    local tpl
    tpl=$(cat <<'NGINXTPL'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen __HTTP_PORT__;
    server_name _;
    return 301 https://$host:__HTTPS_PORT__$request_uri;
}

server {
    listen __HTTPS_PORT__ ssl;
    server_name _;

    ssl_certificate     __CERT__;
    ssl_certificate_key __KEY__;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    client_max_body_size 100m;

    location / {
        proxy_pass http://__UPSTREAM__:__PANEL_PORT__;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
    }
}
NGINXTPL
    )
    tpl=${tpl//__HTTP_PORT__/${http_port}}
    tpl=${tpl//__HTTPS_PORT__/${https_port}}
    tpl=${tpl//__CERT__/${cert}}
    tpl=${tpl//__KEY__/${key}}
    tpl=${tpl//__UPSTREAM__/${upstream}}
    tpl=${tpl//__PANEL_PORT__/${panel_port}}

    if [[ -d /etc/nginx/sites-available ]]; then
        conf_file="/etc/nginx/sites-available/panel.conf"
        echo "${tpl}" >"${conf_file}"
        mkdir -p /etc/nginx/sites-enabled
        rm -f /etc/nginx/sites-enabled/default
        ln -sf "${conf_file}" /etc/nginx/sites-enabled/panel.conf
    else
        conf_file="/etc/nginx/conf.d/panel.conf"
        echo "${tpl}" >"${conf_file}"
    fi

    if ! nginx -t >/dev/null 2>&1; then
        echo -e "${red}nginx 配置校验失败，输出如下：${plain}"
        nginx -t
        return 1
    fi

    systemctl enable nginx >/dev/null 2>&1 || true
    systemctl restart nginx
    sleep 1
    if [[ $(systemctl is-active nginx 2>/dev/null) != "active" ]]; then
        echo -e "${red}nginx 启动失败，请运行 nginx -t 检查${plain}"
        return 1
    fi

    # ---------- 防火墙放行 ----------
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "${http_port}/tcp" >/dev/null 2>&1 || true
        ufw allow "${https_port}/tcp" >/dev/null 2>&1 || true
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="${http_port}/tcp" >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port="${https_port}/tcp" >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    fi

    # ---------- 本机校验 ----------
    local code
    code=$(curl -sk -m 8 -o /dev/null -w '%{http_code}' "https://127.0.0.1:${https_port}/${panel_path}/" 2>/dev/null)
    [[ -z "${pub_ip}" ]] && pub_ip=$(curl -s4m8 https://api.ipify.org 2>/dev/null || echo "YOUR_SERVER_IP")

    echo -e ""
    green "nginx 反代配置完成"
    echo -e "  配置文件      : ${conf_file}"
    echo -e "  证书 / 私钥   : ${cert} / ${key}"
    echo -e "  后端地址      : http://${upstream}:${panel_port}"
    echo -e "  HTTP  ${http_port}   -> 301 跳转至 HTTPS"
    echo -e "  HTTPS ${https_port}  -> 反代面板"
    echo -e "  本机校验      : HTTP ${code:-000}"
    echo -e ""
    green "外网访问地址："
    blue "  https://${pub_ip}:${https_port}/${panel_path}/"
    yellow "首次访问浏览器会提示证书不受信任，选择「高级/继续访问」即可（自签名证书，流量已加密）"
    if [[ "${code}" != "200" && "${code}" != "302" && "${code}" != "301" ]]; then
        yellow "本机校验未返回 200，请确认面板已启动、端口 ${panel_port} 正确，并查看 /var/log/nginx/error.log"
    fi
    return 0
}

install_xray-ui() {
    systemctl stop xray-ui
    cd /usr/local/
    if [ $# == 0 ]; then
        wget --no-check-certificate -O /usr/local/xray-ui-linux-$(arch).tar.gz "${REPO_BASE}/releases/download/${releases_version}/xray-ui-linux-$(arch).tar.gz"
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 xray-ui 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            rm -f install.sh
            exit 1
        fi
    else
        last_version=$1
        url="${REPO_BASE}/releases/download/${releases_version}/xray-ui-linux-$(arch).tar.gz"
        echo -e "开始安装 xray-ui v$1"
        wget  --no-check-certificate -O /usr/local/xray-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 xray-ui v$1 失败，请确保此版本存在${plain}"
            rm -f install.sh
            exit 1
        fi
    fi

    if [[ -e /usr/local/xray-ui/ ]]; then
        rm /usr/local/xray-ui/ -rf
    fi

    tar -zxvf xray-ui-linux-$(arch).tar.gz
    rm xray-ui-linux-$(arch).tar.gz -f
    cd xray-ui
    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi   
    chmod +x xray-ui bin/xray-linux-$(arch)
    cp -f xray-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/xray-ui "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/xray-ui.sh"
    chmod +x /usr/bin/xray-ui
    systemctl daemon-reload
    systemctl enable xray-ui
    systemctl start xray-ui
    sleep 2
    cat >/root/xrayuil.sh <<-\EOF
#!/bin/bash
xui=`ps -aux |grep "xray-ui" |grep -v "grep" |wc -l`
xray=`ps -aux |grep "xray-linux" |grep -v "grep" |wc -l`
sleep 1
if [ $xui = 0 ];then
xray-ui restart
fi
if [ $xray = 0 ];then
xray-ui restart
fi
EOF
    chmod +x /root/xrayuil.sh
    sed -i '/xrayuil.sh/d' /etc/crontab
    echo "*/1 * * * * root bash /root/xrayuil.sh >/dev/null 2>&1" >>/etc/crontab
    sed -i '/xray-ui restart/d' /etc/crontab
    echo "0 1 1 * *  root xray-ui restart >/dev/null 2>&1" >>/etc/crontab
    sleep 1
    echo -e ""
    blue "以下设置内容建议自定义，以防止账号密码路径及端口泄露"
    echo -e ""
    readp "设置xray-ui登录用户名（回车跳过为随机6位字符）：" username
    if [[ -z ${username} ]]; then
        uauto=$(date +%s%N | md5sum | cut -c 1-6)
        username=$uauto
    fi
    sleep 1
    green "xray-ui登录用户名：${username}"
    echo -e ""
    readp "设置xray-ui登录密码（回车跳过为随机6位字符）：" password
    if [[ -z ${password} ]]; then
        pauto=$(date +%s%N | md5sum | cut -c 1-6)
        password=$pauto
    fi
    green "xray-ui登录密码：${password}"
    /usr/local/xray-ui/xray-ui setting -username ${username} -password ${password} >/dev/null 2>&1
    sleep 1
    echo -e ""
    readp "设置xray-ui登录端口[1-65535]（回车跳过为2000-65535之间的随机端口）：" port
    if [[ -z $port ]]; then
        port=$(shuf -i 2000-65535 -n 1)
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义xray-ui端口:" port
        done
    else
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义xray-ui端口:" port
        done
    fi
    /usr/local/xray-ui/xray-ui setting -port $port >/dev/null 2>&1
    green "xray-ui登录端口：${port}"
    sleep 1
    echo -e ""
    readp "设置xray-ui web 路径 （回车跳过为随机10位字符）：" path
    if [[ -z ${path} ]]; then
        path=$(generate_random_string 10)
    fi
    /usr/local/xray-ui/xray-ui setting -webBasePath $path >/dev/null 2>&1
    green "xray-ui web 路径：${path}"
    sleep 1
    xray-ui restart
    ensure_default_compatibility_settings
   }
    xuilogin() {
        v4=$(curl -s4m8 http://ip.sb -k)
        v6=$(curl -s6m8 http://ip.sb -k)
        if [[ -z $v4 ]]; then
            int="${green}请在浏览器地址栏复制${plain}  ${bblue}[$v6]:$ports/$path${plain}  ${green}进入xray-ui登录界面\n当前xray-ui登录用户名：${plain}${bblue}${username}${plain}${green} \n当前xray-ui登录密码：${plain}${bblue}${password}${plain}"
        elif [[ -n $v4 && -n $v6 ]]; then
            int="${green}请在浏览器地址栏复制${plain}  ${bblue}$v4:$ports/$path${plain}  ${yellow}或者${plain}  ${bblue}[$v6]:$ports/$path${plain}  ${green}进入xray-ui登录界面\n当前xray-ui登录用户名：${plain}${bblue}${username}${plain}${green} \n当前xray-ui登录密码：${plain}${bblue}${password}${plain}"
        else
            int="${green}请在浏览器地址栏复制${plain}  ${bblue}$v4:$ports/$path${plain}  ${green}进入xray-ui登录界面\n当前xray-ui登录用户名：${plain}${bblue}${username}${plain}${green} \n当前xray-ui登录密码：${plain}${bblue}${password}${plain}"
        fi
    }
ssh_forwarding() {

  # ========== 获取公网 IP ==========
    local v4=""
    local v6=""
    local Ip=""
    local ip_type=""
    
    v4=$(curl -s4m8 http://ip.sb -k)
    v6=$(curl -s6m8 http://ip.sb -k)

    if [[ -n "${v4}" ]]; then
        Ip="${v4}"
        ip_type="ipv4"
    elif [[ -n "${v6}" ]]; then
        Ip="${v6}"
        ip_type="ipv6"
    else
        Ip="127.0.0.1"
        ip_type="local"
        yellow "无法获取公网 IP，将使用本地回环地址: ${Ip}"
    fi

    # 询问是否申请 SSL 证书
    read -p "$(yellow "是否申请 SSL 证书？输入1申请，输入0跳过（HTTP回环地址访问）: ")" ssl_choice
    if [[ "$ssl_choice" == "1" ]]; then
        # ========== 调用 xray-ui ip_ssl_main ==========
        if ! command -v xray-ui &>/dev/null; then
            red "未检测到 xray-ui，请先安装面板"
            return 1
        fi

        yellow "正在为 IP 申请 SSL 证书..."
        xray-ui ip_ssl_main
        if [[ $? -ne 0 ]]; then
            red "IP SSL 证书申请失败"
            return 1
        fi
        protocol="https"
    else
        yellow "跳过 SSL 证书申请，使用 HTTP 协议访问（本地回环地址）"
        protocol="http"
        Ip="127.0.0.1"
    fi

    ports=$(/usr/local/xray-ui/xray-ui 2>&1 | grep "tcp" | awk '{print $5}' | cut -d':' -f2)

    if [[ -n $ports ]]; then
        # ========== 输出访问地址 ==========
        echo -e ""
        yellow "xray-ui $remoteV 安装成功，请稍等3秒，输出面板登录信息……"
        # xuilogin
        green "面板已配置完成，可通过以下地址访问 xray-ui："

        echo -e "${bblue}${protocol}://${Ip}:${ports}/${path}${plain}"

        echo -e ""
        green "当前 xray-ui 登录信息："
        echo -e "用户名：${bblue}${username}${plain}"
        echo -e "密码：${bblue}${password}${plain}"
        if [[ "$ssl_choice" == "0" ]]; then
        yellow "使用 HTTP，请自行通过 Nginx 或防火墙做端口转发，将 ${Ip}:${ports} 暴露给外网"
        fi
    else
        red "xray-ui安装失败，请查看日志，运行 xray-ui log"
    fi

    sleep 1
    echo -e ""
    echo -e "$int"
    echo -e ""

    green "xray-ui 管理脚本使用方法:"
    echo -e "----------------------------------------------"
    echo -e "xray-ui              - 显示管理菜单"
    echo -e "xray-ui start        - 启动 xray-ui 面板"
    echo -e "xray-ui stop         - 停止 xray-ui 面板"
    echo -e "xray-ui restart      - 重启 xray-ui 面板"
    echo -e "xray-ui status       - 查看 xray-ui 状态"
    echo -e "xray-ui enable       - 设置 xray-ui 开机自启"
    echo -e "xray-ui disable      - 取消 xray-ui 开机自启"
    echo -e "xray-ui log          - 查看 xray-ui 日志"
    echo -e "xray-ui v2-ui        - 迁移本机器的 v2-ui 账号数据至 xray-ui"
    echo -e "xray-ui update       - 更新 xray-ui 面板"
    echo -e "xray-ui geoip        - 更新 geoip ip库"
    echo -e "xray-ui update_shell - 更新 xray-ui 脚本"
    echo -e "xray-ui install      - 安装 xray-ui 面板"
    echo -e "xray-ui x25519       - REALITY  key 生成"
    echo -e "xray-ui ssl_main     - SSL 证书管理"
    echo -e "xray-ui ip_ssl_main  - IP SSL 证书安装"
    echo -e "xray-ui ssl_CF       - Cloudflare SSL 证书"
    echo -e "xray-ui crontab      - 添加 geoip 到任务计划每天凌晨1:30执行"
    echo -e "xray-ui uninstall    - 卸载 xray-ui 面板"
    echo -e "xray-ui nginx_proxy  - nginx 一键反代面板到外网"
    echo -e "----------------------------------------------"

    echo -e ""
    nginx_proxy

    rm -f install.sh
}


echo -e "${green}开始安装xray-ui必要依赖${plain}"
install_base
echo -e "${green}开始安装xray-ui核心组件${plain}"
install_xray-ui $1
echo -e "${green}ip 证书申请 等下信息查询${plain}"
ssh_forwarding