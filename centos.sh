#!/bin/bash

[ "$(id -u)" -ne 0 ] && { echo "Run as root."; exit 1; }

echo "Update!"
dnf update -y

echo "Firewall!"
if ! rpm -q firewalld > /dev/null; then
    dnf install -y firewalld
fi

systemctl start firewalld
systemctl enable firewalld

firewall-cmd --complete-reload
firewall-cmd --permanent --remove-service=ssh
firewall-cmd --permanent --remove-service=dhcpv6-client
firewall-cmd --permanent --remove-port=1-65535/tcp
firewall-cmd --permanent --remove-port=1-65535/udp
firewall-cmd --permanent --delete-rich-rules

for zone in $(firewall-cmd --get-zones | tr ' ' '\n' | grep -vE '^(block|dmz|drop|external|home|internal|public|trusted|work)$'); do
    firewall-cmd --permanent --delete-zone="$zone"
done

firewall-cmd --set-default-zone=drop
firewall-cmd --permanent --set-default-zone=drop

for iface in $(nmcli -t -f DEVICE connection show | grep -v '^$'); do
    firewall-cmd --permanent --zone=drop --add-interface="$iface"
done

firewall-cmd --permanent --zone=drop --add-rich-rule='rule family="ipv4" source address="0.0.0.0/0" reject'
firewall-cmd --permanent --zone=drop --add-rich-rule='rule family="ipv4" destination address="0.0.0.0/0" reject'

firewall-cmd --permanent --zone=drop --add-rich-rule='rule family="ipv6" source address="::/0" reject'
firewall-cmd --permanent --zone=drop --add-rich-rule='rule family="ipv6" destination address="::/0" reject'

firewall-cmd --permanent --zone=drop --add-rich-rule='rule family="ipv4" source address="0.0.0.0/0" port port="80" protocol="tcp" accept'
firewall-cmd --permanent --zone=drop --add-rich-rule='rule family="ipv4" destination address="0.0.0.0/0" port port="80" protocol="tcp" accept'

firewall-cmd --reload

firewall-cmd --list-all

echo "Users!"
for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    [ "$user" != "root" ] && [ "$user" != "sysadmin" ] && userdel -r "$user" 2>/dev/null
done

for user in $(awk -F: '$3 > 0 && $3 < 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    [[ "$user" != "sshd" && "$user" != "chrony" && "$user" != "rpc" && "$user" != "rpcuser" && "$user" != "apache" ]] && userdel -r "$user" 2>/dev/null
done

passwd -l root || { echo "Failed to lock root!"; }

echo "root:NewPassword123!" | chpasswd || { echo "Failed to change root password."; }
echo "sysadmin:NewPassword123!" | chpasswd || { echo "Failed to change sysadmin password."; }

echo "Remaining User List:"
awk -F: '{print $1}' /etc/passwd

echo "OSSEC!"
wget -q -O - https://updates.atomicorp.com/installers/atomic | sudo bash
