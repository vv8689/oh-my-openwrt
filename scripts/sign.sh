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
code_path="$root_path/openwrt"
artifact_root_path="$root_path/artifacts/$version"
artifact_bin_path="$artifact_root_path/targets/$device"
artifact_ipk_path="$artifact_root_path/packages"

# prepare
if [ ! -d openwrt ]; then
    mkdir -p openwrt
fi
cd $code_path

######################## clone awesome-openwrt code ########################
# awesome-openwrt code
do_update_code(){
    echo "update code..."
    cd $code_path
    git pull
    echo -e "$INFO code update done!"
}
do_clone_code(){
    echo "clone code..."
    cd $root_path
    rm -rf $code_path
    # 精简 clone
    git clone --depth 10 -b develop --single-branch https://github.com/awesome-openwrt/openwrt.git $code_path
    echo -e "$INFO code clone done!"
}
clone_or_update_code(){
    if [ ! -d $code_path ]; then
        mkdir -p $code_path
    fi
    result=`ls $code_path`
    if [ -z "$result" ]; then
        do_clone_code
    else
        do_update_code
    fi
}

clone_or_update_code

######################## feeds update and install ########################
# prepare feeds (update and install)
do_pre_feeds(){
    echo "update/install feeds..."
    cd $code_path
    # rm -rf feeds/awesome*
    ./scripts/feeds update -a && ./scripts/feeds install -a
    # ./scripts/feeds update awesome && ./scripts/feeds install -a -p awesome
    echo -e "$INFO update/install feeds done!"
}
pre_feeds(){
    cd $code_path
    if [ -d staging_dir/host/bin  ]; then
        result=`ls staging_dir/host/bin`
        if [ -z "$result" ]; then
            do_pre_feeds
            return
        fi
    else
        do_pre_feeds
        return
    fi
    echo
    while true; do
        echo -n -e "$INPUT"
        read -p "是否 安装/更新 feeds (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_pre_feeds; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
pre_feeds

######################## fix ########################
# 修复 Ubuntu 18.04 动态链接库缺失问题
fix_sys(){
    if [ ! -L /lib/ld-linux-x86-64.so.2 ]; then
        sudo ln -s /lib/x86_64-linux-gnu/ld-2.27.so /lib/ld-linux-x86-64.so.2
    fi
}
# fix_sys

# 修复 v2ray 依赖问题
fix_v2ray_dep(){
    if [ ! -e $code_path/staging_dir/host/bin/upx ]; then
        result=`which upx`
        if [ -n "$result" ]; then
            ln -s $result $code_path/staging_dir/host/bin/upx
        fi
    fi
    if [ ! -e $code_path/staging_dir/host/bin/upx-ucl ]; then
        result=`which upx-ucl`
        if [ -n "$result" ]; then
            ln -s $result $code_path/staging_dir/host/bin/upx-ucl
        fi
    fi
}
fix_v2ray_dep

######################## sign ########################
do_sign(){
    tmp_dir=$1
    cd $tmp_dir
    rm -f Packages*
    $code_path/scripts/ipkg-make-index.sh . 2>/dev/null > Packages.manifest
    grep -vE '^(Maintainer|LicenseFiles|Source|Require)' Packages.manifest > Packages
    gzip -9nc Packages > Packages.gz
    $code_path/staging_dir/host/bin/usign -S -m Packages -s $root_path/openwrt-awesome.key
}
sign_ipks(){
    echo "sign ipks begin..."

    tmp_env=$PATH
    export PATH="$code_path/staging_dir/host/bin:$PATH"

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
    $code_path/staging_dir/host/bin/usign -G -p $root_path/openwrt-awesome.pub -s $root_path/openwrt-awesome.key
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
