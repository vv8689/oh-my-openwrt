# README

用于 Image Builder 生成固件时，保留配置的文件，作用于 `FILES` 参数

## 出厂固件 - factory

### x86

说明:

* `/etc/config/network` 网络配置
* `/etc/config/system` 系统基本配置，如时区、NTP
* `/etc/config/luci` LuCI 配置，如语言、主题
* `/etc/config/uhttpd` uHTTPd 证书设置
* `/etc/config/vlmcsd` KMS 服务器，设置为默认不启动
* `/etc/shadow` 加密后的密码，明文为 password
* `/etc/okpg/customfeeds.conf` 自定义软件源
* `/etc/okpg/distfeeds.conf` 发行版软件源

### 小米路由器青春版

说明:

* `/etc/config/wireless` 无线配置
* `/etc/config/network` 网络配置
* `/etc/config/system` 系统基本配置，如时区、NTP
* `/etc/config/luci` LuCI 配置，如语言、主题
* `/etc/config/vlmcsd` KMS 服务器，设置为默认不启动
* `/etc/shadow` 加密后的密码，明文为 password
* `/etc/okpg/customfeeds.conf` 自定义软件源
* `/etc/okpg/distfeeds.conf` 发行版软件源

## 升级固件 - sysupgrade

### x86

说明:

* `/etc/config/network` 网络配置
* `/etc/config/system` 系统基本配置，如时区、NTP
* `/etc/config/luci` LuCI 配置，如语言、主题
* `/etc/config/uhttpd` uHTTPd 证书设置
* `/etc/config/vlmcsd` KMS 服务器，设置为默认不启动
* `/etc/shadow` 加密后的密码，明文为 password
* `/etc/okpg/customfeeds.conf` 自定义软件源
* `/etc/okpg/distfeeds.conf` 发行版软件源

### 小米路由器青春版

说明:

* `/etc/config/wireless` 无线配置
* `/etc/config/network` 网络配置
* `/etc/config/system` 系统基本配置，如时区、NTP
* `/etc/config/luci` LuCI 配置，如语言、主题
* `/etc/config/vlmcsd` KMS 服务器，设置为默认不启动
* `/etc/config/dhcp` DHCP 配置
* `/etc/config/chinadns` ChinaDNS 配置
* `/etc/config/dns-forwarder` DNS Forwarder 配置
* `/etc/config/shadowsocks` Shadowsocks 配置
* `/etc/config/firewall` 防火墙配置
* `/etc/firewall.user` 防火墙规则
* `/etc/init.d/shadowsocks` Shadowsocks 启动脚本修改，增加 iptables 转发 gfwlist 流量
* `/etc/rc.local` 启动脚本，初次启动时，更新 Chnroute 和 GFWList dnsmasq_gfwlist_ipset.conf
* `/etc/crontabs/root` 计划任务，每天更新 Chnroute 和 GFWList dnsmasq_gfwlist_ipset.conf
* `/root/update_chnroute_dnsmasqconf_list.sh` Chnroute 和 GFWList dnsmasq_gfwlist_ipset.conf 的更新脚本
* `/etc/chinadns_chnroute.txt` Chnroute 国内 IP 路由表
* `/etc/dnsmasq.d/dnsmasq_gfwlist_ipset.conf` GFWList dnsmasq_gfwlist_ipset.conf
* `/etc/dnsmasq.conf` dnsmasq 配置文件，添加自定义配置目录
* `/etc/shadow` 加密后的密码，明文为 password
* `/etc/okpg/customfeeds.conf` 自定义软件源
* `/etc/okpg/distfeeds.conf` 发行版软件源