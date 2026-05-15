-- Source: https://www.scriptdba.com/installazione-oracle-linux-8-su-virtualbox-6/
-- Title: Installazione Oracle Linux 8 su VirtualBox 6

vi /etc/sysconfig/network-script/ifcfg-enp0s8

vi /etc/sysconfig/network-script/ifcfg-enp0s8

#Parametri da non modificare
TYPE=Ethernet
NAME=enp0s8
UUID=40f3b72c-84e5-4ae0-a66c-d5e455ac8d0f
DEVICE=enp0s8

#Parametri da modificare
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
ONBOOT=yes
BROADCAST=192.168.3.255
GATEWAY=192.168.3.1
IPADDR=192.168.3.10
NETMASK=255.255.255.0
NM_CONTROLLED=yes
USERCTL=no

#Parametri da non modificare
TYPE=Ethernet
NAME=enp0s8
UUID=40f3b72c-84e5-4ae0-a66c-d5e455ac8d0f
DEVICE=enp0s8

#Parametri da modificare
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
ONBOOT=yes
BROADCAST=192.168.3.255
GATEWAY=192.168.3.1
IPADDR=192.168.3.10
NETMASK=255.255.255.0
NM_CONTROLLED=yes
USERCTL=no

