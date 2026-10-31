#!/bin/sh


# 1. 太平洋电脑网 IP API
# 响应格式: if(window.IPCallBack) {IPCallBack({"ip":"202.27.85.42","err":""});}
echo "1. PConline IP:"
curl -s https://whois.pconline.com.cn/ipJson.jsp | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}'

# 2. DDNSPOD IPv4
# 响应格式: 19.27.81.42
echo "2. DDNSPOD IP:"
curl -s https://ipv4.ddnspod.com

# 3. 花生壳 Oray CheckIP
# 响应格式: Current IP Address: 13.27.8.4
echo -e "\n3. Oray IP:"
curl -s https://ddns.oray.com/checkip | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}'

# 4. 中国科学技术大学 IP
# 响应格式: 您的IP地址: 19.27.8.2来
echo "4. USTC IP:"
curl -s https://ip.ustc.edu.cn/ | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}'



INTERFACE="br-lan"
TOKEN=""
DOMAIN="19991999.dynv6.net"
INTERVAL=600
# ===================================================

LAST_IP=""
IS_FIRST_RUN=1

log_to_sys() {
    #echo "$1"
    logger -t "dynv6" "$1"
}

if [ -z "$token" ]; then
    log_to_sys "Token not set."
    exit 1
fi

# 检查系统是否安装了必需的 curl 工具
if ! command -v curl >/dev/null 2>&1; then
    log_to_sys "CRITICAL ERROR: 'curl' is required but not installed."
    exit 1
fi

log_to_sys "Daemon started. Checking interface: $INTERFACE every $INTERVAL seconds."

while true; do
    # 动态匹配中国联通(2408)、移动(2409)、电信(240e)等公网 IPv6
    CURRENT_IP=$(ip -6 addr show dev "$INTERFACE" scope global | grep -oE '240[89a-fA-F]:[a-fA-F0-9:]+' | head -n 1)

    if [ -n "$CURRENT_IP" ]; then
        if [ $IS_FIRST_RUN -eq 1 ] || [ "$CURRENT_IP" != "$LAST_IP" ]; then
            
            CURRENT_IP2=$(echo "$CURRENT_IP" | cut -d':' -f1-4):68:52:87:1
            RESPONSE=$(curl -4 -s "https://dynv6.com/api/update?zone=${DOMAIN}&token=${TOKEN}&ipv6=${CURRENT_IP2}")
            
            case "$RESPONSE" in
                *updated*|*unchanged*)
                    log_to_sys "Success. IP/Prefix [$CURRENT_IP/64] registered. (Response: $RESPONSE)"
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
            log_to_sys "WARNING: No valid public IPv6 address (starting with 240x) found."
            LAST_IP=""
        fi
    fi
    sleep "$INTERVAL"
done
