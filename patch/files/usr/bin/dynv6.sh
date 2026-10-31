#!/bin/sh


INTERFACE="br-lan"
TOKEN=""
DOMAIN="en19991999.dynv6.net"
INTERVAL=600
# ===================================================

LAST_IP=""
IS_FIRST_RUN=1
CHECK_IPV6=0

function get_public_ipv4() {
    # 1. 太平洋电脑网 IP API
    ip1=$(curl -s --max-time 5 https://whois.pconline.com.cn/ipJson.jsp | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n 1)
    ip1="${ip1%.}"
    # 2. DDNSPOD IPv4
    ip2=$(curl -s --max-time 5 https://ipv4.ddnspod.com)
    ip2="${ip2%.}"
    # 3. 花生壳 Oray CheckIP
    ip3=$(curl -s --max-time 5 https://ddns.oray.com/checkip | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n 1)
    ip3="${ip3%.}"
    # 4. 中国科学技术大学 IP
    #ip4=$(curl -s --max-time 5 https://ip.ustc.edu.cn/ | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n 1)

    # 使用 awk 统计 IP 出现次数（POSIX sh 兼容）
    max_ip=$(printf '%s\n' "$ip1" "$ip2" "$ip3" | grep -E '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sort | uniq -c | sort -rn | head -n 1)
    max_count=$(echo "$max_ip" | awk '{print $1}')
    max_ip=$(echo "$max_ip" | awk '{print $2}')

    # 如果最大票数 >= 2，返回该 IP；否则返回空字符串
    if [ "$max_count" -ge 2 ] 2>/dev/null; then
        echo "$max_ip"   
    else
        echo ""
    fi
}

log_to_sys() {
    #echo "$1"
    logger -t "dynv6" "$1"
}

if [ -z "$TOKEN" ]; then
    log_to_sys "Token not set."
    exit 1
fi

# 检查系统是否安装了必需的 curl 工具
if ! command -v curl >/dev/null 2>&1; then
    log_to_sys "CRITICAL ERROR: 'curl' is required but not installed."
    exit 1
fi

log_to_sys "Daemon started. Checking every $INTERVAL seconds on $INTERFACE for IPV6."

while true; do
    # 动态匹配中国联通(2408)、移动(2409)、电信(240e)等公网 IPv6
    CURRENT_IP=$(ip -6 addr show dev "$INTERFACE" scope global | grep -oE '240[89a-fA-F]:[a-fA-F0-9:]+' | head -n 1)
    if [ -n "$CURRENT_IP" ]; then
        if [ $IS_FIRST_RUN -eq 1 ] || [ "$CURRENT_IP" != "$LAST_IP" ]; then
            if [ $CHECK_IPV6 -eq 1 ]; then
                tail=68:52:87:1
            else
                ipv4=$(get_public_ipv4)
                tail=$(echo "$ipv4" | tr '.' ':')
            fi
            CURRENT_IP2=$(echo "$CURRENT_IP" | cut -d':' -f1-4):$tail
            RESPONSE=$(curl -4 -s "https://dynv6.com/api/update?zone=${DOMAIN}&token=${TOKEN}&ipv6=${CURRENT_IP2}")
            
            case "$RESPONSE" in
                *updated*|*unchanged*)
                    log_to_sys "Success. IP [$CURRENT_IP2] registered. (Response: $RESPONSE)"
                    LAST_IP="$CURRENT_IP"
                    IS_FIRST_RUN=0
                    ;;
                *)
                    log_to_sys "ERROR: Registration failed. Current IP: $CURRENT_IP, Response: $RESPONSE"
                    ;;
            esac
        fi
    else
        if [ $IS_FIRST_RUN -eq 1 ] || [ -n "$LAST_IP" ]; then
            log_to_sys "WARNING: No valid public IP address found."
            LAST_IP=""
        fi
    fi
    sleep "$INTERVAL"
done
