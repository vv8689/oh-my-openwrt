#!/bin/sh

set -e -o pipefail

# update chnroute list
wget --no-check-certificate https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt -O /tmp/china_ip_list.txt && mv /tmp/china_ip_list.txt /etc/chinadns_chnroute.txt

# update dnsmasq.conf list
wget --no-check-certificate https://stuarthua.github.io/gfwlist/dnsmasq_gfwlist_ipset.conf -O /tmp/dnsmasq_gfwlist_ipset.conf && mv /tmp/dnsmasq_gfwlist_ipset.conf /etc/dnsmasq.d/dnsmasq_gfwlist_ipset.conf

if pidof ss-redir >/dev/null; then
    /etc/init.d/shadowsocks restart
fi