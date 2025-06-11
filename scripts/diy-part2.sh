#!/bin/bash
# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

function merge_package() {
    # 参数1是分支名,参数2是库地址,参数3是所有文件下载到指定路径。
    # 同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开。
    if [[ $# -lt 3 ]]; then
        echo "Syntax error: [$#] [$*]" >&2
        return 1
    fi
    trap 'rm -rf "$tmpdir"' EXIT
    branch="$1" curl="$2" target_dir="$3" && shift 3
    rootdir="$PWD"
    localdir="$target_dir"
    [ -d "$localdir" ] || mkdir -p "$localdir"
    tmpdir="$(mktemp -d)" || exit 1
    git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$curl" "$tmpdir"
    cd "$tmpdir"
    git sparse-checkout init --cone
    git sparse-checkout set "$@"
    # 使用循环逐个移动文件夹
    for folder in "$@"; do
        mv -f "$folder" "$rootdir/$localdir"
    done
    cd "$rootdir"
}

# 更新 golang 1.24 版本
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang

### 个性化设置
sed -i 's/iStoreOS/StoneOS/' package/istoreos-files/files/etc/board.d/10_system
sed -i 's/192.168.100.1/10.0.0.1/' package/istoreos-files/Makefile
# 加入作者信息
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='StoneOS-$(date +%Y%m%d)'/g"  package/base-files/files/etc/openwrt_release
sed -i "s/DISTRIB_REVISION='*.*'/DISTRIB_REVISION=' By Stone'/g" package/base-files/files/etc/openwrt_release
# 更换默认背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/third/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
# 更换banner
cp -f $GITHUB_WORKSPACE/images/banner package/base-files/files/etc/banner
# TTYD
sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
# 修改默认密码
sed -i 's/root:::0:99999:7:::/root:$1$5mjCdAB1$Uk1sNbwoqfHxUmzRIeuZK1:0:0:99999:7:::/g' package/base-files/files/etc/shadow

# iStoreOS-settings
git clone --depth=1 -b main https://github.com/s71557/istoreos-settings package/default-settings

# 添加第三方应用
mkdir kiddin9
pushd kiddin9
git clone --depth=1 https://github.com/kiddin9/kwrt-packages .
popd
mkdir package/community
pushd package/community
#Onliner
mkdir luci-app-onliner
cp -rf ../../kiddin9/luci-app-onliner/* luci-app-onliner


# 科学上网和代理应用
git clone https://github.com/sbwml/openwrt_helloworld package/helloworld

#OpenClash
mkdir luci-app-openclash
cp -rf ../../kiddin9/luci-app-openclash/* luci-app-openclash
#加入打开Clash核心
chmod -R a+x $GITHUB_WORKSPACE/scripts/preset-clash-core.sh
if [ "$1" = "rk33xx" ]; then
    $GITHUB_WORKSPACE/scripts/preset-clash-core.sh arm64
elif [ "$1" = "rk35xx" ]; then
    $GITHUB_WORKSPACE/scripts/preset-clash-core.sh arm64
elif [ "$1" = "x86" ]; then
    $GITHUB_WORKSPACE/scripts/preset-clash-core.sh amd64
elif [ "$1" = "x86-alpha" ]; then
    $GITHUB_WORKSPACE/scripts/preset-clash-core.sh amd64    
fi

# 添加第三方应用
echo "

# 科学上网和代理应用
#Openclash
CONFIG_PACKAGE_luci-app-openclash=y

" >> .config

# 额外组件
echo "
CONFIG_GRUB_IMAGES=y
CONFIG_VMDK_IMAGES=y
# CONFIG_ISO_IMAGES=y
CONFIG_QCOW2_IMAGES=y
" >> .config
