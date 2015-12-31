#!/bin/bash
# Bestehende Tables löschen
iptables -F

# Alle eingehenden Verbindungen verbieten
iptables -P INPUT DROP
iptables -P FORWARD DROP

# Alle ausgehenden erlauben
iptables -P OUTPUT ACCEPT

# Traffic auf port 7070 (sshd) und 4040 (http) und 5050 (https) erlauben
iptables -A INPUT -j ACCEPT -p tcp --dport 4040
iptables -A INPUT -j ACCEPT -p tcp --dport 5050
iptables -A INPUT -j ACCEPT -p tcp --dport 7070



# Alles von Localhost erlauben. (Damit der Server selbst ungehindert auf seine Dienste zugreifen kann,
# zum Beispiel PHP auf die lokale Datenbank
iptables -A INPUT -j ACCEPT -s 127.0.0.1

# Bereits aufgebaute Verbindungen werden an jedem Port akzeptiert
# (Damit Antworten auf Anfragen, die vom Server kommen immer zurückkommen können)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT