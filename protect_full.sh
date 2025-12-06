#!/bin/bash
clear

echo ""
echo "======================================"
echo "   🚨 INSTALL FULL DDoS PROTECTION"
echo "   Layer 4 • Layer 7 • Layer 2 Shield"
echo "   + AUTO BAN IP ATTACKERS"
echo "======================================"
echo ""

sleep 1

###############################################
#  UPDATE SYSTEM
###############################################
echo "[1] Updating system..."
apt update -y >/dev/null 2>&1
apt install -y curl wget ufw nginx fail2ban >/dev/null 2>&1

###############################################
#  LAYER 4 FIREWALL PROTECTION
###############################################
echo "[2] Applying Layer 4 protection..."

cat <<EOF >/etc/sysctl.conf
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1

# Anti DDOS
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_fin_timeout = 15
net.ipv4.icmp_echo_ignore_all = 0
EOF

sysctl -p >/dev/null 2>&1

###############################################
#  IPTABLES (L4 DDOS PROTECT + AUTO BAN)
###############################################
echo "[3] Setting iptables rules..."

iptables -F
iptables -X

# block invalid
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# limit ping
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT

# syn flood protect
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# connection limit
iptables -A INPUT -p tcp --syn -m limit --limit 30/s --limit-burst 50 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# udp flood limit
iptables -A INPUT -p udp -m limit --limit 20/s --limit-burst 40 -j ACCEPT
iptables -A INPUT -p udp -j DROP

# AUTO BAN attacker flood
iptables -N DDOS-FILTER
iptables -A INPUT -p tcp -m recent --name DDOS --set
iptables -A INPUT -p tcp -m recent --name DDOS --update --seconds 2 --hitcount 20 -j DROP

# allow ssh & nginx
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

iptables -A INPUT -j DROP


###############################################
#  LAYER 2 FILTER
###############################################
echo "[4] Enabling Layer 2 protections..."

echo 2 > /proc/sys/net/ipv4/conf/all/arp_filter
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route


###############################################
#  FAIL2BAN (AUTO BAN)
###############################################
echo "[5] Configuring Fail2Ban AutoBan..."

cat <<EOF >/etc/fail2ban/jail.local
[nginx-http]
enabled = true
filter = nginx-http
logpath = /var/log/nginx/access.log
maxretry = 20
findtime = 10
bantime = 3600

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 3
EOF

cat <<EOF >/etc/fail2ban/filter.d/nginx-badbots.conf
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*HTTP.*"(python|curl|wget|bot|crawler|spider|attack)
EOF

systemctl restart fail2ban


###############################################
#  LAYER 7 PROTECTION (NGINX Anti-BOT)
###############################################
echo "[6] Configuring Layer 7 AntiBot..."

cat <<EOF >/etc/nginx/conf.d/antiddos.conf
limit_req_zone \$binary_remote_addr zone=one:10m rate=30r/s;

server {
    listen 80 default_server;
    server_name _;

    # Rate Limit (HTTP FLOOD)
    limit_req zone=one burst=50 nodelay;

    # Block Bad User Agents
    if (\$http_user_agent ~* (curl|wget|python|java|bot|crawler|spider)) {
        return 403;
    }

    # Slowloris protect
    client_header_timeout 10s;
    client_body_timeout 10s;
    keepalive_timeout 10s;

    # Prevent large requests
    client_max_body_size 1m;

    # Auto-ban via fail2ban (logs)
    access_log /var/log/nginx/access.log;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

systemctl restart nginx


###############################################
#  BBR BOOSTER (NETWORK SPEED)
###############################################
echo "[7] Enabling BBR..."

modprobe tcp_bbr
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf

cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sysctl -p >/dev/null 2>&1


###############################################
#  DONE
###############################################
echo ""
echo "======================================"
echo "     ✅ FULL DDoS PROTECTION ACTIVE"
echo "     + AUTO BAN IP ATTACKERS"
echo "======================================"
echo ""
echo "• Layer 4 (iptables + sysctl)"
echo "• Layer 7 (Nginx AntiBot)"
echo "• Layer 2 (ARP / RP Filter)"
echo "• Auto Ban: Fail2Ban + IPTables Recent"
echo ""
echo "Selesai!"