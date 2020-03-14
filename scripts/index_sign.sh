#!/usr/bin/env bash

BOLD="\033[1m"
NORM="\033[0m"
INFO="$BOLD Info: $NORM"
INPUT="$BOLD => $NORM"
ERROR="\033[31m *** Error: $NORM"
WARNING="\033[33m * Warning: $NORM"

# if error occured, then exit
set -e

# prepare
if [ ! -d build_openwrt ]; then
    mkdir -p build_openwrt
fi
cd build_openwrt

# path
root_path=`pwd`
project="lean-openwrt"
code_path="$root_path/lean-openwrt"
# 1 小米路由器青春版, 2 Newifi3, 3 软路由
device_type=3
# 1 lean, 2 18.06.8, 3 19.07.2
index_type=1

######################## download app code from lean openwrt rep ########################
do_update_code(){
    echo "update code..."
    cd $code_path
    git pull origin master 1>/dev/null 2>&1
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

######################## index and sign ########################
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

gen_index(){
    tmp_dir=$1
    cd $tmp_dir
    # echo "cur dir: $tmp_dir"
    rm -f Packages*
    $code_path/scripts/ipkg-make-index.sh . 2>/dev/null > Packages.manifest
    grep -vE '^(Maintainer|LicenseFiles|Source|Require)' Packages.manifest > Packages
    gzip -9nc Packages > Packages.gz
    $code_path/staging_dir/host/bin/usign -S -m Packages -s $root_path/openwrt-stuart.key
}

index_ipk(){
    echo "gen ipks index begin..."

    tmp_env=$PATH
    export PATH="$code_path/staging_dir/host/bin:$PATH"

    if [ ! -d $1/luci ]; then
        mkdir -p $1/luci
    fi
    if [ ! -d $1/base/$device ]; then
        mkdir -p $1/base/$device
    fi

    gen_index "$1/luci"
    gen_index "$1/base/$device"

    unset PATH
    export PATH="$tmp_env"
    
    echo -e "$INFO gen ipks index done!"
}

dir_index_ipk(){
    artifact_path="$root_path/artifacts"
    if [ $index_type -eq 1 ]; then
        artifact_root_path="$artifact_path/lean"
    elif [ $index_type -eq 2 ]; then
        artifact_root_path="$artifact_path/18.06.8"
    elif [ $index_type -eq 3 ]; then
        artifact_root_path="$artifact_path/19.07.2"
    else
        echo -e "$INFO End!"
        exit
    fi

    artifact_ipk_path="$artifact_root_path/packages"
    index_ipk "$artifact_ipk_path"
}

# gen key
if [ ! -e $root_path/openwrt-stuart.key ]; then
    echo "openwrt-stuart.key gen..."
    $code_path/staging_dir/host/bin/usign -G -p $root_path/openwrt-stuart.pub -s $root_path/openwrt-stuart.key
    echo -e "$INFO openwrt-stuart.key gen done!"
fi

while true; do
    echo -n -e "$INPUT"
    read -p "请选择路由器设备 ( 0/1/2/3 | 0 取消, 1 小米路由器青春版, 2 Newifi3, 3 软路由 ) : " yn
    echo
    case $yn in
        1 ) device_type=1; gen_device_desc; break;;
        2 ) device_type=2; gen_device_desc; break;;
        3 ) device_type=3; gen_device_desc; break;;
        0 ) echo -e "$INFO End!"; exit;;
        "" ) gen_device_desc; break;;
        * ) echo "输入 1(小米), 2(Newifi3), 3(软路由) 或 0(取消) 以确认";;
    esac
done

while true; do
    echo -n -e "$INPUT"
    read -p "请选择需要索引的目录 ( 0/1/2/3 | 0 取消, 1 lean, 2 18.06.8, 3 19.07.2 ) : " yn
    echo
    case $yn in
        1 ) index_type=1; dir_index_ipk; break;;
        2 ) index_type=2; dir_index_ipk; break;;
        3 ) index_type=3; dir_index_ipk; break;;
        0  | "") echo -e "$INFO End!"; exit;;
        * ) echo "输入 1(lean), 2(18.06.8), 3(19.07.2) 或 0(取消) 以确认";;
    esac
done
