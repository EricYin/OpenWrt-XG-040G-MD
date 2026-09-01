#!/bin/bash
# 安装和更新第三方软件包
# 此脚本在 openwrt/package/ 目录下运行，在 feeds install 之后执行

build_mode="$1"
echo "Build mode: $build_mode"

UPDATE_FEED_PACKAGE() {  
    local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local GIT_URL="https://github.com/$PKG_REPO.git" 
	local FEED_DIR="../myluci"
    echo "Installing $PKG_NAME from $GIT_URL ..."
    if [ ! -d "$FEED_DIR" ]; then
        echo "create feed app dir: $FEED_DIR..."
	    mkdir -vp $FEED_DIR
    fi
	
    git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "$GIT_URL" "$FEED_DIR/$PKG_NAME"
    ls $FEED_DIR/$PKG_NAME
	if [ ! -d "$FEED_DIR/$PKG_NAME" ]; then
		echo "ERROR: Failed to clone $PKG_REPO"
		return 1
	fi

	local OLD=$PWD
	cd $FEED_DIR/$PKG_NAME
    local REAL_PATH=$PWD
	echo $REAL_PATH
	cd $OLD
	local SRC_LINK="src-link $PKG_NAME $REAL_PATH"
	echo $SRC_LINK
	echo "$SRC_LINK" >> ../feeds.conf.default
	cat ../feeds.conf.default
	../scripts/feeds update $PKG_NAME
    ../scripts/feeds install -a -p $PKG_NAME
	return 0
}

UPDATE_PACKAGE() {
	local -n PKG_NAMES=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local REPO_NAME=${PKG_REPO#*/}

	echo " "
	echo "=========================================="
	(IFS=" | "; echo "Processing: ${PKG_NAMES[*]} from $PKG_REPO, repository: $REPO_NAME, branch: $PKG_BRANCH" )
	echo "=========================================="

	# 删除 feeds 中可能存在的同名软件包
	for NAME in "${PKG_NAMES[@]}"; do
	    if [ -z "$NAME" ]; then
		    continue
		fi
		
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		if [ -n "$FOUND_DIRS" ]; then
		    while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"

	if [ ! -d "$REPO_NAME" ]; then
	    ls
		echo "ERROR: Failed to clone $PKG_REPO"
		return 1
	fi

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
	   for NAME in "${PKG_NAMES[@]}"; do
		    if [[ "$REPO_NAME" == "$NAME" ]]; then
			   echo "Rename repository folder to ${REPO_NAME}1 as it is same as target pkg folder"
			   mv ./$REPO_NAME ./${REPO_NAME}1
			   REPO_NAME=${REPO_NAME}1
			   break
			fi
		done
		# 从大杂烩仓库中提取特定包
		for NAME in "${PKG_NAMES[@]}"; do
	        if [ -z "$NAME" ]; then
		        continue
		    fi
		    find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$NAME*" -prune -exec cp -rf {} ./ \;
		done
		rm -rf ./$REPO_NAME/
	# elif [[ "$PKG_SPECIAL" == "name" ]]; then
		# 重命名仓库
	#	mv -f $REPO_NAME $PKG_NAME
	fi
	
    (IFS=" | "; echo "Done: ${PKG_NAMES[*]}")
}

PATCH_PASSWALL_GLOBAL_LUA() {
	local CANDIDATES=(
		"./luci-app-passwall/luasrc/model/cbi/passwall/client/global.lua"
		"./passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/global.lua"
	)
	local FOUND=0

	for FILE in "${CANDIDATES[@]}"; do
		if [ -f "$FILE" ]; then
			FOUND=1
			echo "Applying PassWall Lua compatibility hotfix: $FILE"

			# Guard optional form fields to avoid nil-index runtime errors.
			sed -i 's#local dns_shunt_val = s.fields\["dns_shunt"\]:formvalue(section)#local dns_shunt_val = (s.fields["dns_shunt"] and s.fields["dns_shunt"]:formvalue(section)) or ""#g' "$FILE"
			sed -i 's#s.fields\["dns_mode"\]:formvalue(section) == "xray" or s.fields\["smartdns_dns_mode"\]:formvalue(section) == "xray"#((s.fields["dns_mode"] and s.fields["dns_mode"]:formvalue(section)) == "xray") or ((s.fields["smartdns_dns_mode"] and s.fields["smartdns_dns_mode"]:formvalue(section)) == "xray")#g' "$FILE"
			sed -i 's#s.fields\["dns_mode"\]:formvalue(section) == "sing-box" or s.fields\["smartdns_dns_mode"\]:formvalue(section) == "sing-box"#((s.fields["dns_mode"] and s.fields["dns_mode"]:formvalue(section)) == "sing-box") or ((s.fields["smartdns_dns_mode"] and s.fields["smartdns_dns_mode"]:formvalue(section)) == "sing-box")#g' "$FILE"
		fi
	done

	if [ "$FOUND" -eq 0 ]; then
		echo "WARNING: PassWall global.lua not found, hotfix skipped."
	fi
}

echo "Starting package updates..."

# 首先删除 feeds 中的 sing-box 相关包，避免与第三方包冲突
echo " "
echo "=========================================="
echo "Removing conflicting sing-box packages from feeds..."
echo "=========================================="
rm -rf ../feeds/packages/net/sing-box
rm -rf ../package/feeds/packages/sing-box
echo "Done removing sing-box from feeds"

# HomeProxy (代理软件) - 使用第5个参数指定额外要删除的包名
pkgs=("sing-box"); UPDATE_PACKAGE pkgs "ericyin/luci-app-homeproxy" "main" "pkg"; unset pkgs
pkgs=("luci-app-homeproxy"); UPDATE_PACKAGE pkgs "ericyin/luci-app-homeproxy" "main" "pkg"; unset pkgs
#pkgs=("homeproxy"); UPDATE_PACKAGE pkgs "immortalwrt/homeproxy" "master"; unset pkgs

# soc status app
pkgs=("luci-app-airoha-npu"); UPDATE_PACKAGE pkgs "ericyin/luci-app-airoha-npu" "main"; unset pkgs
sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' ./luci-app-airoha-npu/Makefile

# windows/office tool
vlmcsd_branch=""
if [[ $build_mode == openwrt-25.12.* ]]; then
	vlmcsd_branch="openwrt-25.12"
elif [[ $build_mode == main ]]; then
	vlmcsd_branch="master"
fi

if [[ -n "$vlmcsd_branch" ]]; then
    pkgs=("vlmcsd"); UPDATE_PACKAGE pkgs "immortalwrt/packages" "$vlmcsd_branch" "pkg"; unset pkgs
    pkgs=("luci-app-vlmcsd"); UPDATE_PACKAGE pkgs "immortalwrt/luci"  "$vlmcsd_branch" "pkg"; unset pkgs
    sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' ./luci-app-vlmcsd/Makefile
fi

# file explorer
pkgs=("luci-app-quickfile-go"); UPDATE_PACKAGE pkgs "ericyin/luci-app-quickfile-go" "main" "pkg"; unset pkgs

# 
# Argon 主题
pkgs=("luci-theme-argon"); UPDATE_PACKAGE pkgs "jerrykuku/luci-theme-argon" "master"; unset pkgs
pkgs=("luci-app-argon-config"); UPDATE_PACKAGE pkgs "jerrykuku/luci-app-argon-config" "master"; unset pkgs

# 修改 LuCI 默认主题为 Argon（保留 bootstrap 包可共存）
echo " "
echo "=========================================="
echo "Setting default LuCI theme to argon..."
echo "=========================================="
COLLECTION_MAKEFILES=$(find ../feeds/luci/collections/ -type f -name "Makefile" 2>/dev/null)
if [ -n "$COLLECTION_MAKEFILES" ]; then
	sed -i "s/luci-theme-bootstrap/luci-theme-argon/g" $COLLECTION_MAKEFILES
	echo "Done setting default LuCI theme to argon"
else
	echo "WARNING: No LuCI collection Makefile found, skip theme default patch"
fi

if [ -n "$OPT_PASSWALL" ] && [ "$OPT_PASSWALL" -eq 1 ]; then
	# PassWall (代理软件)
	pkgs=("passwall"); UPDATE_PACKAGE pkgs "Openwrt-Passwall/openwrt-passwall" "main" "pkg"; unset pkgs
	PATCH_PASSWALL_GLOBAL_LUA
	
	# OpenWrt 25.12 下 shadowsocksr-libev 的上游归档内容已变化，旧 MIRROR_HASH 失效。
	# 先禁用 SSR 组件，避免 passwall 选择该包导致下载阶段直接失败。
	PASSWALL_MAKEFILE="./luci-app-passwall/Makefile"
	if [ -f "$PASSWALL_MAKEFILE" ]; then
		echo "Patching PassWall defaults to disable broken ShadowsocksR components..."
		sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Client/,/default y/s/default y/default n/' "$PASSWALL_MAKEFILE"
		sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Server/,/default n/s/default n/default n/' "$PASSWALL_MAKEFILE"
	fi
	
	# PassWall 依赖包
	echo " "
	echo "=========================================="
	echo "Installing PassWall dependencies..."
	echo "=========================================="
	git clone --depth=1 --single-branch --branch main "https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git"
	if [ -d "openwrt-passwall-packages" ]; then
		for pkg in openwrt-passwall-packages/*/; do
			pkg_name=$(basename "$pkg")
			if [ -d "$pkg" ] && [ -f "$pkg/Makefile" ]; then
				echo "Installing: $pkg_name"
				rm -rf "./$pkg_name"
				cp -rf "$pkg" ./
			fi
		done
		rm -rf openwrt-passwall-packages
	fi
fi

echo " "
echo "=========================================="
echo "Package updates completed, list packages folder: "
ls
echo "=========================================="
