#!/usr/bin/env bash

BOLD="\033[1m"
NORM="\033[0m"
INFO="$BOLD Info: $NORM"
INPUT="$BOLD => $NORM"
ERROR="\033[31m *** Error: $NORM"
WARNING="\033[33m * Warning: $NORM"

# if error occured, then exit
set -e

# info
# device_type: 1 小米路由器青春版, 2 Newifi3, 3 软路由
echo -e "$INFO Awesome OpenWrt 当前支持以下路由器设备:"
echo
echo "        1. 小米路由器青春版"
echo "        2. Newifi3"
echo "        3. 软路由"
echo
echo "        0. 取消"
echo

while true; do
    echo -n -e "$INPUT"
    read -p "请选择路由器设备类型: " yn
    echo
    case $yn in
        1 ) device_type=1; break;;
        2 ) device_type=2; break;;
        3 ) device_type=3; break;;
        0  | "") echo -e "$INFO End!"; exit;;
        * ) echo "输入 0-9 以确认";;
    esac
done

gen_device_desc(){
    version="19.07.2"

    if [ $device_type -eq 1 ]; then
        device="xiaomi"
        cpu_arch="mipsel_24kc"
    elif [ $device_type -eq 2 ]; then
        device="newifi3"
        cpu_arch="mipsel_24kc"
    elif [ $device_type -eq 3 ]; then
        device="x86_64"
        cpu_arch="x86_64"
    else
        echo -e "$INFO End!"
        exit
    fi
}

gen_device_desc

# prepare
if [ ! -d build ]; then
    mkdir -p build
fi
script_root_path=`pwd`
cd build

# path
root_path=`pwd`
signtool_path="$root_path/signtool"
artifact_root_path="$root_path/artifacts/$version"
artifact_bin_path="$artifact_root_path/targets/$device"
artifact_ipk_path="$artifact_root_path/packages"

######################## set env ########################
pre_signtool(){
    cd $root_path
    if [ -d $signtool_path ]; then
        echo -e "$INFO signtool already set done!"
    else
        echo "set signtool..."
        wget -O sdk.tar.xz -t 5 -T 60 https://mirrors.ustc.edu.cn/lede/releases/19.07.2/targets/ramips/mt76x8/openwrt-sdk-19.07.2-ramips-mt76x8_gcc-7.5.0_musl.Linux-x86_64.tar.xz
        echo "download signtool done."
        echo "extract signtool..."
        tar -xvf sdk.tar.xz 1>/dev/null 2>&1
        mv openwrt-sdk-$version-* sdk
        rm -rf sdk.tar.xz
        echo -e "$INFO set signtool done."
    fi
}
pre_signtool

######################## feeds update and install ########################
# prepare feeds (update and install)
do_pre_feeds(){
    echo "update/install feeds..."
    cd $signtool_path
    ./scripts/feeds update -a && ./scripts/feeds install -a
    # ./scripts/feeds update awesome && ./scripts/feeds install -a -p awesome
    echo -e "$INFO update/install feeds done!"
}
pre_feeds(){
    cd $signtool_path
    if [ -d staging_dir/host/bin  ]; then
        result=`find staging_dir/host/bin -name "usign"`
        if [ -z "$result" ]; then
            do_pre_feeds
            return
        fi
    else
        do_pre_feeds
        return
    fi
}
pre_feeds

######################## fix ########################
# 修复 Ubuntu 18.04 动态链接库缺失问题
fix_sys(){
    if [ ! -L /lib/ld-linux-x86-64.so.2 ]; then
        sudo ln -s /lib/x86_64-linux-gnu/ld-2.27.so /lib/ld-linux-x86-64.so.2
    fi
}
fix_sys

######################## sign ########################
do_sign(){
    tmp_dir=$1
    cd $tmp_dir
    rm -f Packages*
    $signtool_path/scripts/ipkg-make-index.sh . 2>/dev/null > Packages.manifest
    grep -vE '^(Maintainer|LicenseFiles|Source|Require)' Packages.manifest > Packages
    gzip -9nc Packages > Packages.gz
    $signtool_path/staging_dir/host/bin/usign -S -m Packages -s $root_path/openwrt-awesome.key
}
sign_ipks(){
    echo "sign ipks begin..."

    tmp_env=$PATH
    export PATH="$signtool_path/staging_dir/host/bin:$PATH"

    if [ ! -d $1/luci ]; then
        mkdir -p $1/luci
    fi
    if [ ! -d $1/base/$cpu_arch ]; then
        mkdir -p $1/base/$cpu_arch
    fi

    do_sign "$1/luci"
    do_sign "$1/base/$cpu_arch"

    unset PATH
    export PATH="$tmp_env"
    
    echo -e "$INFO sign ipks done."
}
sign_dir_ipks(){
    artifact_path="$root_path/artifacts"

    if [ $index_type -eq 1 ]; then
        artifact_root_path="$artifact_path/19.07.2"
    else
        echo -e "$INFO End!"
        exit
    fi

    artifact_ipk_path="$artifact_root_path/packages"
    sign_ipks "$artifact_ipk_path"
}

# gen key
if [ ! -e $root_path/openwrt-awesome.key ]; then
    echo "openwrt-awesome.key gen..."
    $signtool_path/staging_dir/host/bin/usign -G -p $root_path/openwrt-awesome.pub -s $root_path/openwrt-awesome.key
    echo -e "$INFO openwrt-awesome.key gen done!"
fi

while true; do
    echo -n -e "$INPUT"
    read -p "请选择需要索引的目录 ( 0/1 | 0 取消, 1 19.07.2 ) : " yn
    echo
    case $yn in
        1 ) index_type=1; break;;
        0  | "") echo -e "$INFO End!"; exit;;
        * ) echo "输入 1(19.07.2) 或 0(取消) 以确认";;
    esac
done

sign_dir_ipks
