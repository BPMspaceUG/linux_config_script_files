#!/bin/bash
# flush old ruleset
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Allows all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0
# Erlaube interne Kommuninkation ueber loopback 
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT ! -i lo -d 127.0.0.0/8 -j REJECT

# bestehende Verbindungen werden nicht blockiert
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ausgehende Verbindungen sind erlaubt
iptables -A OUTPUT -j ACCEPT

# leite Port 4040 auf 5050 weiter
iptables -A PREROUTING -t nat -p tcp --dport 4040 -j REDIRECT --to-port 5050

# https/5050, ssh/7070 sind erlaubt
iptables -A INPUT -p tcp --dport 5050 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW --dport 7070 -j ACCEPT

# falls man mal ICMP zulassen will
#iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT

# Verstoesse werden protokolliert
# iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

# any - any - deny Regel fuer INPUT und FORWARD chain
iptables -A INPUT -j REJECT
iptables -A FORWARD -j REJECT
