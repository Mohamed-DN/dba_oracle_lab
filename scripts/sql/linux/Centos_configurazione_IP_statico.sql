-- Source: https://www.scriptdba.com/centos-configurazione-ip-statico/
-- Title: Centos configurazione IP statico

cd /etc/sysconfig/network-script

cd /etc/sysconfig/network-script

vi ifcfg-enp0s8

vi ifcfg-enp0s8

BOOTPROTO=static
 
IPV6INIT=no
 
IPV6_AUTOCONF=no

BOOTPROTO=static
 
IPV6INIT=no
 
IPV6_AUTOCONF=no

IPADDR=192.168.10.10 

NETMASK=255.255.255.0 

GATEWAY=192.168.10.1

IPADDR=192.168.10.10 

NETMASK=255.255.255.0 

GATEWAY=192.168.10.1

