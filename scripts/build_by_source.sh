#!/usr/bin/env bash

BOLD="\033[1m"
NORM="\033[0m"
INFO="$BOLD Info: $NORM"
INPUT="$BOLD => $NORM"
ERROR="\033[31m *** Error: $NORM"
WARNING="\033[33m * Warning: $NORM"

# if error occured, then exit
set -e

######################## setting env ########################
# common
project="awesome-openwrt"
# 1 小米路由器青春版, 2 Newifi3, 3 软路由
device_type=3

gen_device_desc(){
    if [ $device_type -eq 1 ]; then
        device="xiaomi"
        device_ipk_desc="mipsel_24kc"
        device_bin_desc="ramips/mt76x8"
    elif [ $device_type -eq 2 ]; then
        device="newifi3"
        device_ipk_desc="newifi3"
        device_bin_desc="ramips/newifi3"
    elif [ $device_type -eq 3 ]; then
        device="x86_64"
        device_ipk_desc="x86_64"
        device_bin_desc="x86/x86_64"
    else
        echo -e "$INFO End!"
        exit
    fi
}
while true; do
    echo -n -e "$INPUT"
    read -p "请选择路由器设备 ( 0/1/2/3 | 0 取消, 1 小米路由器青春版, 2 Newifi3, 3 软路由 ) : " yn
    echo
    case $yn in
        1 ) device_type=1; gen_device_desc; break;;
        2 ) device_type=2; gen_device_desc; break;;
        3 ) device_type=3; gen_device_desc; break;;
        0  | "") echo -e "$INFO End!"; exit;;
        * ) echo "输入 1(小米), 2(Newifi3), 3(软路由) 或 0(取消) 以确认";;
    esac
done

# prepare
if [ ! -d build_openwrt ]; then
    mkdir -p build_openwrt
fi
cd build_openwrt

# path
root_path=`pwd`
code_path="$root_path/$project"
stuart_path="$root_path/stuart-openwrt"
ipk_path="$code_path/bin/packages/$device_ipk_desc"
bin_path="$code_path/bin/targets/$device_bin_desc"
artifact_root_path="$root_path/artifacts/lean"
artifact_bin_path="$artifact_root_path/targets/$device"
artifact_ipk_path="$artifact_root_path/packages"

######################## set env ########################
# dir for project and artifact
pre_artifacts_dir(){
    if [ ! -d $code_path ]; then
        mkdir -p $code_path
    fi
    if [ ! -d $bin_path ]; then
        mkdir -p $bin_path
    fi
    if [ ! -d $ipk_path/stuart ]; then
        mkdir -p $ipk_path/stuart
    fi
    if [ ! -d $artifact_root_path ]; then
        mkdir -p $artifact_root_path
    fi
    if [ ! -d $artifact_bin_path ]; then
        mkdir -p $artifact_bin_path
    fi
    if [ ! -d $artifact_ipk_path ]; then
        mkdir -p $artifact_ipk_path
    fi
    if [ ! -d $artifact_ipk_path/luci ]; then
        mkdir -p $artifact_ipk_path/luci
    fi
    if [ ! -d $artifact_ipk_path/base ]; then
        mkdir -p $artifact_ipk_path/base
        mkdir -p $artifact_ipk_path/base/$device
    fi
    echo -e "$INFO artifact dir set done!"
}
pre_artifacts_dir

######################## download app code from lean openwrt rep ########################
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
    git clone https://github.com/coolsnowwolf/lede.git $project
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
# 修复 18.04 动态链接库缺失问题
fix_sys(){
    if [ ! -L /lib/ld-linux-x86-64.so.2 ]; then
        sudo ln -s /lib/x86_64-linux-gnu/ld-2.27.so /lib/ld-linux-x86-64.so.2
    fi
}
fix_sys
# feeds download
do_update_feeds(){
    echo "download feeds begin..."
    cd $code_path
    ./scripts/feeds update -a && ./scripts/feeds install -a
    echo -e "$INFO download feeds done!"
}
update_feeds(){
    cd $code_path
    if [ -d staging_dir/host/bin  ]; then
        result=`ls staging_dir/host/bin`
        if [ -z "$result" ]; then
            do_update_feeds
            return
        fi
    else
        do_update_feeds
        return
    fi
    while true; do
        echo -n -e "$INPUT"
        read -p "是否 安装/更新 feeds (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_update_feeds; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
update_feeds

######################## build config ########################
default_config(){
    cd $code_path
    if [ ! -e .config ]; then
        if [ -d $stuart_path/devices_config ]; then
            if [ $device_type -eq 1 ]; then
                cp -f $stuart_path/devices_config/lean/xiaomi.config .config
            elif [ $device_type -eq 2 ]; then
                cp -f $stuart_path/devices_config/lean/newifi3.config .config
            elif [ $device_type -eq 3 ]; then
                cp -f $stuart_path/devices_config/lean/x86_64.config .config
            fi
        fi
    fi
}
choose_config(){
    cd $code_path
    while true; do
        echo -n -e "$INPUT"
        read -p "是否需要修改编译配置 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) make menuconfig; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
default_config
choose_config

######################## build openwrt ########################
archive_bin(){
    cd $bin_path
    cp -f openwrt-*-squashfs-sysupgrade.bin $artifact_bin_path
}
do_build_openwrt(){
    echo "build begin..."
    cd $code_path
    make download
    make V=s
    echo -e "$INFO build done!"
    
    # 归档 bin
    archive_bin
}
build_openwrt(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否开始编译 lean openwrt 固件 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_build_openwrt; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
build_openwrt

######################## build ipks ########################
do_build_linux(){
    echo "build linux begin..."
    cd $code_path
    # make menuconfig
    make target/linux/compile V=s
    echo -e "$INFO build linux done!"
}
build_linux(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否开始编译 Linux 内核 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_build_linux; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
build_linux

archive_ssr_ipk(){
    cd $ipk_path/base
    cp -f luci-app-ssr-plus*_all.ipk $artifact_ipk_path/luci/
    # dependency
    sudo cp -f shadowsocksr-libev-*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
    cp -f libopenssl*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
    cp -f ipt2socks*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
    cp -f microsocks*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
    cp -f pdnsd-alt*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
    cp -f simple-obfs*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
    cp -f v2ray*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
    cp -f trojan*$device_ipk_desc.ipk $artifact_ipk_path/base/$device/
}

do_build_ssr_ipk(){
    echo "build ssr begin..."
    cd $code_path
    # make menuconfig
    make package/lean/luci-app-ssr-plus/compile V=s
    echo -e "$INFO build ssr done!"

    # 归档 ipks
    archive_ssr_ipk
}
build_ssr_ipk(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否开始编译 SSR 软件包 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_build_ssr_ipk; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
build_ssr_ipk