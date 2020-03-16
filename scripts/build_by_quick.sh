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
    bin_ext=".bin"

    if [ $device_type -eq 1 ]; then
        device="xiaomi"
        cpu1="ramips"
        cpu2="mt76x8"
        cpu_arch="mipsel_24kc"
        device_profile="miwifi-nano"
    elif [ $device_type -eq 2 ]; then
        device="newifi3"
        cpu1="ramips"
        cpu2="mt7621"
        cpu_arch="mipsel_24kc"
        device_profile="d-team_newifi-d2"
    elif [ $device_type -eq 3 ]; then
        device="x86_64"
        cpu1="x86"
        cpu2="64"
        cpu_arch="x86_64"
        device_profile="x86"
    else
        echo -e "$INFO End!"
        exit
    fi

    # OpenWrt 官方
    # base_url="http://downloads.openwrt.org/releases"
    # 清华大学镜像站
    # base_url="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases"
    # 中科大镜像站
    base_url="https://mirrors.ustc.edu.cn/lede/releases"
    
    imagebuilder_url="$base_url/$version/targets/$cpu1/$cpu2/openwrt-imagebuilder-$version-$cpu1-$cpu2.Linux-x86_64.tar.xz"
    sdk_url="$base_url/$version/targets/$cpu1/$cpu2/openwrt-sdk-$version-$cpu1-${cpu2}_gcc-${gcc_version}_musl.Linux-x86_64.tar.xz"
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
sdk_path="$device_path/sdk"
ipk_path="$sdk_path/bin/packages/$cpu_arch"
imagebuilder_path="$device_path/imagebuilder"
bin_path="$imagebuilder_path/bin/targets/$cpu1/$cpu2"
artifact_root_path="$root_path/artifacts/$version"
artifact_bin_path="$artifact_root_path/targets/$device"
artifact_ipk_path="$artifact_root_path/packages"

# prepare
if [ ! -d $device ]; then
    mkdir -p $device
fi
cd $device_path

######################## set env ########################
# image builder
pre_imagebuilder(){
    if [ -d imagebuilder ]; then
        echo -e "$INFO imagebuilder already set done!"
    else
        echo "download imagebuilder..."
        wget -O imagebuilder.tar.xz -t 5 -T 60 $imagebuilder_url
        echo "download imagebuilder done."
        echo "extract imagebuilder..."
        tar -xvf imagebuilder.tar.xz 1>/dev/null 2>&1
        mv openwrt-imagebuilder-$version-* imagebuilder
        rm -f imagebuilder.tar.xz
        echo -e "$INFO imagebuilder set done."
    fi
}
pre_imagebuilder

# sdk
pre_sdk(){
    if [ -d sdk ]; then
        echo -e "$INFO sdk already set done!"
    else
        echo "download sdk..."
        wget -O sdk.tar.xz -t 5 -T 60 $sdk_url
        echo "download sdk done."
        echo "extract sdk..."
        tar -xvf sdk.tar.xz 1>/dev/null 2>&1
        mv openwrt-sdk-$version-* sdk
        rm -rf sdk.tar.xz
        echo -e "$INFO sdk set done."
    fi
}
pre_sdk

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
pre_archive_dir

######################## feeds update and install ########################
# add packages to feeds.conf
add_packages2feeds(){
    # import awesome code to sdk
    if [ `grep -c "src-git awesome https://github.com/awesome-openwrt/openwrt-packages" $sdk_path/feeds.conf.default` -eq 0 ]; then
        echo "add packages to feeds..."
        echo "src-git awesome https://github.com/awesome-openwrt/openwrt-packages">>$sdk_path/feeds.conf.default
        echo -e "$INFO add packages to feeds done!"
    fi
}
add_packages2feeds

# prepare feeds (update and install)
do_pre_feeds(){
    echo "update/install feeds..."
    cd $sdk_path
    # rm -rf feeds/awesome*
    ./scripts/feeds update -a && ./scripts/feeds install -a
    # ./scripts/feeds update awesome && ./scripts/feeds install -a -p awesome
    echo -e "$INFO update/install feeds done!"
}
pre_feeds(){
    cd $sdk_path
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

######################## pre build ########################
# make menuconfig
do_make_menuconfig(){
    cd $sdk_path
    make menuconfig
}
default_config(){
    cd $sdk_path
    if [ ! -e .config ]; then
        diffconfig_file_path="$script_root_path/devices/$device/source-diffconfig.info"
        if [ -e $diffconfig_file_path ]; then
            cp -f $diffconfig_file_path .config
            make defconfig
        fi
    fi
}
edit_config(){
    cd $sdk_path
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
    cd $sdk_path
    if [ -d dl ]; then
        # @https://p3terx.com/archives/openwrt-compilation-steps-and-commands.html
        # 查找 dl 目录下文件是否下载正常，小于 1k 的文件，说明下载可能不完整
        result="find dl -size -1024c -exec ls -l {} \;"
        if [ -n "$result" ]; then
            # # 删除 dl 目录下小于 1k 的文件
            find dl -size -1024c -exec rm -f {} \;
            make download -j8 V=s
        fi
    else
        make download -j8 V=s
    fi
}
download_dep(){
    cd $sdk_path
    while true; do
        echo -n -e "$INPUT"
        read -p "是否需要下载编译依赖 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_make_download; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
download_dep

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
    if [ ! -e $sdk_path/staging_dir/host/bin/upx ]; then
        result=`which upx`
        if [ -n "$result" ]; then
            ln -s $result $sdk_path/staging_dir/host/bin/upx
        fi
    fi
    if [ ! -e $sdk_path/staging_dir/host/bin/upx-ucl ]; then
        result=`which upx-ucl`
        if [ -n "$result" ]; then
            ln -s $result $sdk_path/staging_dir/host/bin/upx-ucl
        fi
    fi
}
fix_v2ray_dep

######################## build ########################

# build ipks
do_build_ipks(){
    echo "build ipks begin..."

    cd $sdk_path

    # clean dir
    rm -rf $ipk_path/awesome
    mkdir -p $ipk_path/awesome

    ################# start build for detail ######################

    # 查看自定义软件包 ./scripts/feeds list -r awesome

    # make package/luci-app-usb-printer/compile V=s                    # luci USB 打印服务器

    # make package/ddns-scripts_aliyun/compile V=s                     # aliyun ddns
    # make package/vlmcsd/compile V=s                                  # KMS 服务器
    # make package/luci-app-arpbind/compile V=s                        # luci 静态 ARP 绑定
    # make package/luci-app-autoreboot/compile V=s                     # luci 定时重启
    # make package/luci-app-fileassistant/compile V=s                  # luci 文件助手
    # make package/luci-app-ipsec-vpnd/compile V=s                     # luci IPSec VPN
    # make package/luci-app-mia/compile V=s                            # luci 上网时间控制
    # make package/luci-app-ramfree/compile V=s                        # luci 释放内存
    # make package/luci-app-timewol/compile V=s                        # luci 定时唤醒
    # make package/luci-app-ttyd/compile V=s                           # luci 网页终端
    # make package/luci-app-vlmcsd/compile V=s                         # luci KMS 服务器
    # make package/luci-app-webadmin/compile V=s                       # luci Web 管理
    # make package/luci-app-webrestriction/compile V=s                 # luci 访问控制
    # make package/luci-app-weburl/compile V=s                         # luci 网址过滤
    # make package/luci-app-xlnetacc/compile V=s                       # luci 迅雷快鸟
    # make package/luci-i18n-sqm/compile V=s                           # sqm 语言包

    ############## Test
    # make package/v2ray/compile V=s
    # make package/trojan/compile V=s
    make package/luci-app-passwall-mini/compile V=s
    make package/luci-app-ssr-plus-mini/compile V=s

    ################# end build for detail ######################

    echo -e "$INFO build ipks done!"
}
build_ipks(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否编译 Awesome OpenWrt 软件包 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) do_build_ipks; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
build_ipks

# 归档 ipks
do_archive_ipks(){
    cd $ipk_path/awesome
    cp -f *_all.ipk $artifact_ipk_path/luci
    cp -f *_$cpu_arch.ipk $artifact_ipk_path/base/$cpu_arch
}
archive_ipks(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否归档 ipks 软件包 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* | "" ) do_archive_ipks; break;;
            [Nn]* ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}
result=`ls $ipk_path/awesome`
if [ -n "$result" ]; then
    archive_ipks
fi

# build img
do_build_bin(){
    echo "build $build_type bin begin..."

    cd $imagebuilder_path

    # clean
    rm -rf $bin_path
    mkdir -p $bin_path
    rm -rf $imagebuilder_path/packages/awesome

    # add ipks to imagebuilder
    mkdir -p $imagebuilder_path/packages/awesome
    cp -f $artifact_ipk_path/luci/* $imagebuilder_path/packages/awesome/
    cp -f $artifact_ipk_path/base/$cpu_arch/* $imagebuilder_path/packages/awesome/
    # cp -r $ipk_path/awesome $imagebuilder_path/packages

    # 查看固件已安装软件包 echo $(opkg list_installed | awk '{ print $1 }')
    org_original_pkgs="base-files busybox dnsmasq dropbear firewall fstools fwtool hostapd-common ip6tables iptables iw iwinfo jshn jsonfilter kernel kmod-cfg80211 kmod-gpio-button-hotplug kmod-ip6tables kmod-ipt-conntrack kmod-ipt-core kmod-ipt-nat kmod-ipt-offload kmod-leds-gpio kmod-lib-crc-ccitt kmod-mac80211 kmod-mt76 kmod-mt76-core kmod-mt7603 kmod-mt76x02-common kmod-mt76x2 kmod-mt76x2-common kmod-nf-conntrack kmod-nf-conntrack6 kmod-nf-flow kmod-nf-ipt kmod-nf-ipt6 kmod-nf-nat kmod-nf-reject kmod-nf-reject6 kmod-nls-base kmod-ppp kmod-pppoe kmod-pppox kmod-slhc libblobmsg-json libc libgcc libip4tc libip6tc libiwinfo libiwinfo-lua libjson-c libjson-script liblua liblucihttp liblucihttp-lua libnl-tiny libpthread libubox libubus libubus-lua libuci libuclient libxtables logd lua luci luci-app-firewall luci-base luci-lib-ip luci-lib-jsonc luci-lib-nixio luci-mod-admin-full luci-proto-ipv6 luci-proto-ppp luci-theme-bootstrap mtd netifd odhcp6c odhcpd-ipv6only openwrt-keyring opkg ppp ppp-mod-pppoe procd rpcd rpcd-mod-rrdns swconfig ubox ubus ubusd uci uclient-fetch uhttpd usign wireless-regdb wpad-mini"
    org_custom_pkgs="luci-i18n-base-zh-cn -kmod-usb-core -kmod-usb2 -kmod-usb-ohci -kmod-usb-ledtrig-usbport luci-i18n-firewall-zh-cn libustream-mbedtls ca-bundle ca-certificates wget curl vsftpd openssh-sftp-server -dnsmasq dnsmasq-full"

    # 查看自定义软件包 ./scripts/feeds list -r awesome
    ## factory
    awesome_factory_pkgs="luci-app-ramfree luci-app-fileassistant luci-app-arpbind luci-i18n-arpbind-zh-cn luci-app-autoreboot luci-i18n-autoreboot-zh-cn ttyd luci-app-ttyd luci-i18n-ttyd-zh-cn luci-app-webadmin luci-i18n-webadmin-zh-cn"
    ## sysupgrade
    awesome_sysupgrade_pkgs="$awesome_factory_pkgs vlmcsd luci-app-vlmcsd luci-i18n-vlmcsd-zh-cn luci-app-ipsec-vpnd luci-i18n-ipsec-vpnd-zh-cn sqm-scripts luci-app-sqm"

    if [ $build_type == "factory" ]; then
        image_pkgs="$org_original_pkgs $org_custom_pkgs $awesome_factory_pkgs"
        files_path="$script_root_path/devices/$device/factory"
    else
        image_pkgs="$org_original_pkgs $org_custom_pkgs $awesome_sysupgrade_pkgs"
        files_path="$script_root_path/devices/$device/sysupgrade"
    fi

    if [ -d $files_path ]; then
        make image PROFILE=$device_profile PACKAGES="${image_pkgs}" FILES=$files_path
    else
        make image PROFILE=$device_profile PACKAGES="${image_pkgs}"
    fi

    echo -e "$INFO build $build_type bin done!"
}

choose_build_type(){
    while true; do
        echo -n -e "$INPUT"
        read -p "请选择固件类型 ( 0/1/2 | 0 取消, 1 出厂固件, 2 升级固件 ) : " yn
        echo
        case $yn in
            1 ) build_type="factory"; do_build_bin; break;;
            2 ) build_type="sysupgrade"; do_build_bin; break;;
            0  | "") echo -e "$INFO 取消编译"; break;;
            * ) echo "输入 1(出厂固件), 2(升级固件) 或 0(取消) 以确认";;
        esac
    done
}

build_bin(){
    while true; do
        echo -n -e "$INPUT"
        read -p "是否编译 Awesome OpenWrt 固件 (y/n) ? " yn
        echo
        case $yn in
            [Yy]* ) choose_build_type; break;;
            [Nn]* | "" ) break;;
            * ) echo "输入 y 或 n 以确认";;
        esac
    done
}

result=`ls $artifact_ipk_path/luci/*.ipk`
if [ -n "$result" ]; then
    build_type="factory"
    build_bin
fi

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
result=`ls $bin_path/*${bin_ext}`
if [ -n "$result" ]; then
    archive_bins
fi

echo -e "$INFO End!"