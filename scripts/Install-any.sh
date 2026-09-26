#./openwrt
mkdir -p ./files/etc/init.d/ 
mkdir -p ./files/usr/bin
mkdir -p ./files/etc/uci-defaults
cp ../scripts/dynv6.sh ./files/usr/bin/dynv6.sh
cp ../scripts/dynv6d ./files/etc/init.d/dynv6d
cp ../scripts/99-init-dynv6 ./files/etc/uci-defaults/99-init-dynv6
