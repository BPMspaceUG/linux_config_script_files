#!/bin/bash

NETWORK=$1

case $NETWORK in

   dhcp)
       echo "iface $IFACE inet dhcp"
       ;;


   static)
       read -p "Please enter IP address:" IP
       read -p "Please enter Netmask:" NETMASK
       read -p "Please enter Gateway:" GATEWAY
       read -p "Please enter Primary DNS resolver:" DNS
       echo "IP: $IP"
       echo "NETMASK: $NETMASK"
       echo "GATEWAY: $GATEWAY"
       echo "DNS: $DNS"
       read -p "Korrekt? (y|n)" ok
       
       case $ok in
          y|Y)
	   echo "Haut"
	   ;;

	  n|N)
	   echo "Abbruch"
	   exit 1
	   ;;

	  *)
	   echo "falsche Eingabe"
	   exit 1
	   ;;
        esac
       ;;

esac
