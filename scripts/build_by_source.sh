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
    gcc_version="7.5.0"

    if [ $device_type -eq 1 ]; then
        device="xiaomi"
        cpu1="ramips"
        cpu2="mt76x8"
        cpu_arch="mipsel_24kc"
        bin_ext=".bin"
    elif [ $device_type -eq 2 ]; then
        device="newifi3"
        cpu1="ramips"
        cpu2="mt7621"
        cpu_arch="mipsel_24kc"
        bin_ext=".bin"
    elif [ $device_type -eq 3 ]; then
        device="x86_64"
        cpu1="x86"
        cpu2="64"
        cpu_arch="x86_64"
        bin_ext=".img.gz"
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
device_path="$root_path/$device"
code_path="$device_path/openwrt"
ipk_path="$code_path/bin/packages/$cpu_arch"
bin_path="$code_path/bin/targets/$cpu1/$cpu2"
artifact_root_path="$root_path/artifacts/$version"
artifact_bin_path="$artifact_root_path/targets/$device"
artifact_ipk_path="$artifact_root_path/packages"

# prepare
if [ ! -d $device ]; then
    mkdir -p $device
fi
cd $device_path

######################## set env ########################
# archive dir
pre_archive_dir(){
    ## dir bins
    if [ ! -d $bin_path ]; then
        mkdir -p $bin_path
    fi
    # 软链接，方便快速查看
    if [ ! -L $device_path/bins ]; then
        ln -s $bin_path $device_path/bins
    fi
    # 归档构建产物
    if [ ! -d $artifact_bin_path ]; then
        mkdir -p $artifact_bin_path
    fi
    ## dir ipks
    if [ ! -d $ipk_path/awesome ]; then
        mkdir -p $ipk_path/awesome
    fi
    # 软链接，方便快速查看
    if [ ! -L $device_path/ipks ]; then
        ln -s $ipk_path $device_path/ipks
    fi
    # 归档构建产物
    if [ ! -d $artifact_ipk_path ]; then
        mkdir -p $artifact_ipk_path
    fi
    if [ ! -d $artifact_ipk_path/luci ]; then
        mkdir -p $artifact_ipk_path/luci
    fi
    if [ ! -d $artifact_ipk_path/base/$cpu_arch ]; then
        mkdir -p $artifact_ipk_path/base/$cpu_arch
    fi
    echo -e "$INFO archive dir already set done!"
}

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

pre_archive_dir

######################## feeds update and install ########################
# add packages to feeds.conf
add_packages2feeds(){
    # import awesome-openwrt code
    if [ `grep -c "src-git awesome https://github.com/awesome-openwrt/openwrt-packages" $code_path/feeds.conf.default` -eq 0 ]; then
        echo "add packages to feeds..."
        echo "src-git awesome https://github.com/awesome-openwrt/openwrt-packages">>$code_path/feeds.conf.default
        echo -e "$INFO add packages to feeds done!"
    fi
}
add_packages2feeds

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

######################## pre build ########################
# make menuconfig
do_make_menuconfig(){
    cd $code_path
    make menuconfig
}
default_config(){
    cd $code_path
    if [ ! -e .config ]; then
        diffconfig_file_path="$script_root_path/devices/$device/source-diffconfig.info"
        if [ -e $diffconfig_file_path ]; then
            cp -f $diffconfig_file_path .config
            make defconfig
        fi
    fi
}
edit_config(){
    cd $code_path
    default_config
    while true; do
        echo -n -e "$INPUT"
        read -p "是否需要修改编译配置 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_make_menuconfig; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
edit_config

# make download
do_make_download(){
    cd $code_path
    if [ -d dl ]; then
        # @https://p3terx.com/archives/openwrt-compilation-steps-and-commands.html
        # 查找 dl 目录下文件是否下载正常，小于 1k 的文件，说明下载可能不完整
        result="find dl -size -1024c -exec ls -l {} \;"
        if [ -n "$result" ]; then
            # 删除 dl 目录下小于 1k 的文件
            find dl -size -1024c -exec rm -f {} \;
            make download -j8 V=s
        fi
    else
        make download -j8 V=s
    fi
}
download_dep(){
    cd $code_path
    while true; do
        echo -n -e "$INPUT"
        read -p "是否下载编译依赖 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_make_download; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
download_dep

######################## build ########################

# build bin
do_build_bin(){
    echo "build $device bin begin..."

    cd $code_path

    # 首次编译推荐单线程编译，以防玄学问题
    # make j=1 V=s
    # 自动获取 CPU 线程数，采用多线程编译，成功编译后再次编译且没有进行 make clean 操作时使用
    make -j$(nproc) V=s

    echo -e "$INFO build $device bin done!"
}
build_bin(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否编译 Awesome OpenWrt 固件 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_build_bin; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}

build_bin

# 归档 bins
do_archive_bins(){
    cd $bin_path
    cp -f openwrt-${version}*${bin_ext} $artifact_bin_path/awesome-openwrt-$version-$device-$build_type${bin_ext}
}

archive_bins(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否归档固件 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* | "" ) do_archive_bins; break;;
            [Nn]* ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}

result=`find $bin_path -name "openwrt-${version}*${bin_ext}"`
if [ -n "$result" ]; then
    archive_bins
fi

echo -e "$INFO End!"