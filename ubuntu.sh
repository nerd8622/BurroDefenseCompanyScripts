#!/bin/bash

[ "$(id -u)" -ne 0 ] && { echo "Run as root."; exit 1; }

echo "Update!"
apt update -y && apt upgrade -y

echo "Firewall!"
if ! dpkg -l | grep -q ufw; then
    apt install -y ufw
fi

ufw --force enable
ufw --force reset

ufw default deny incoming
ufw default deny outgoing

ufw allow in proto tcp from any to any port 20,21
ufw allow out proto tcp from any to any port 20,21
ufw allow in proto tcp from any to any port 30000:31000
ufw allow out proto tcp from any to any port 30000:31000

ufw status

echo "Users!"
for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    [ "$user" != "root" ] && [ "$user" != "sysadmin" ] && userdel -r "$user" 2>/dev/null
done

for user in $(awk -F: '$3 > 0 && $3 < 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    [[ "$user" != "sshd" && "$user" != "chrony" && "$user" != "rpc" && "$user" != "rpcuser" && "$user" != "ftp" ]] && userdel -r "$user" 2>/dev/null
done

passwd -l root || { echo "Failed to lock root!"; }

echo "root:NewPassword123!" | chpasswd || { echo "Failed to change root password."; }
echo "sysadmin:NewPassword123!" | chpasswd || { echo "Failed to change sysadmin password."; }

passwd -S root | grep -q "locked" || { echo "Root not locked."; }

echo "Remaining User List:"
awk -F: '{print $1}' /etc/passwd

echo "Perms FTP"
chown ftp:ftp  /var/ftp/OreCTF-Simple-Logo.png
chmod 400 /var/ftp/OreCTF-Simple-Logo.png
chmod 500 /var/ftp/

echo "OSSEC!"
wget -q -O - https://updates.atomicorp.com/installers/atomic | sudo bash
