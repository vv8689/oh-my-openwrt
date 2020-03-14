#!/usr/bin/env bash

BOLD="\033[1m"
NORM="\033[0m"
INFO="$BOLD Info: $NORM"
INPUT="$BOLD => $NORM"
ERROR="\033[31m *** Error: $NORM"
WARNING="\033[33m * Warning: $NORM"

# tips
echo -e "$INFO Welcome to Awesome OpenWrt oh-my-openwrt!"
echo
echo "        1. 编译 Awesome OpenWrt for xiaomi"
echo "        2. 编译 Awesome OpenWrt for newifi3"
echo "        3. 编译 Awesome OpenWrt for x86_64"
echo "        8. 索引 ipks 并签名 (此过程无需翻墙!)"
echo "        9. 安装编译所需软件包 (此过程无需翻墙!)"
echo "        0. 更新 oh-my-openwrt"
echo

do_update_omo(){
    echo "update oh-my-openwrt..."
    git reset --hard
    git clean -fd
    git pull
    echo -e "$INFO oh-my-openwrt update done!"
}

while true; do
    echo -n -e "$INPUT"
    read -p "请输入操作序号 (0-9): " yn
    echo
    case $yn in
        "" ) echo -e "$INFO Exit!"; exit;;
        0 ) do_update_omo; exit;;

        1 ) bash scripts/xiaomi-r1cl.sh; break;;
        2 ) bash scripts/newifi3.sh; break;;
        3 ) bash scripts/x86_64.sh; break;;

        8 ) bash scripts/index_sign.sh; exit;;
        9 ) bash scripts/dependency.sh; break;;
        * ) echo "输入 0-9 以确认";;
    esac
done

echo
