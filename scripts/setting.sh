#!/bin/bash

apply_sed_to_matches() {
	local SEARCH_DIR=$1
	local FILE_NAME=$2
	local SED_EXPR=$3
	local MATCHES

	MATCHES=$(find "$SEARCH_DIR" -type f -name "$FILE_NAME" 2>/dev/null)
	if [ -n "$MATCHES" ]; then
		while IFS= read -r TARGET_FILE; do
			sed -i "$SED_EXPR" "$TARGET_FILE"
		done <<< "$MATCHES"
	fi
}

#移除luci-app-attendedsysupgrade
apply_sed_to_matches "./feeds/luci/collections/" "Makefile" "/attendedsysupgrade/d"

#修改默认主题
#sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#sed -i "s/luci-theme-.*$/luci-theme-bootstrap/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

#修改immortalwrt.lan关联IP
apply_sed_to_matches "./feeds/luci/modules/luci-mod-system/" "flash.js" "s/192\\.168\\.[0-9]*\\.[0-9]*/$WRT_IP/g"
#添加编译日期标识
apply_sed_to_matches "./feeds/luci/modules/luci-mod-status/" "10_system.js" "s/(\\(luciversion || ''\\))/(\\1) + (' \\/ $WRT_DATE')/g"

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

#配置文件修改
#echo "CONFIG_PACKAGE_luci=y" >> ./.config
#echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
#echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
#echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config


