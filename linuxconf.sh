#!/bin/bash

# Text Colours
  bold=$(tput bold)      # ${bold}
  normal=$(tput sgr0)    # ${normal}
  yellow=$(tput setaf 3) # ${yellow}

# Variables - Credit Lordify

# Deleting password for the script to run uninterrapted

    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-$USER
    echo "Defaults timestamp_timeout=-1" | sudo tee -a /etc/sudoers

# Kérjük be a felhasználótól az IP-címet
  read -p "Add meg az IP-címet (pl. 192.168.0.254/24): " user_ip
  read -p "Add meg a subnetet (DHCP pl. 192.168.0.0): " subnet_ip
  read -p "Add meg a netmaskot (DHCP pl. 255.255.255.0): " netmask_ip
  read -p "Add meg a scopeot (DHCP pl. 192.168.0.10 192.168.0.200): " scope_ip
  read -p "Add meg a dns server ip címét (DHCP pl. 192.168.0.254): " domains_ip
  read -p "Add meg a domain nevet (pl. cegnev.local): " domain_name

# Ellenőrizzük, hogy az IP-cím formátuma helyes-e
if [[ ! $user_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo ${bold}${yellow}Hibás IP-cím formátum! Példa helyes formátumra: 192.168.1.2/24${normal}
    exit 1
fi

# Ellenőrizzük, hogy a subnet IP formátuma helyes-e
if [[ ! $subnet_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo ${bold}${yellow}Hibás subnet IP formátum! Példa helyes formátumra: 192.168.0.0${normal}
    exit 1
fi

# Ellenőrizzük, hogy a netmask IP formátuma helyes-e
if [[ ! $netmask_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo ${bold}${yellow}Hibás netmask IP formátum! Példa helyes formátumra: 255.255.255.0${normal}
    exit 1
fi

# Ellenőrizzük, hogy a scope IP tartomány formátuma helyes-e
# A scope ip tartománynak két IP-t kell tartalmaznia, szóközökkel elválasztva (pl. 192.168.0.10 192.168.0.200)
if [[ ! $scope_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo${bold}${yellow}Hibás scope IP formátum! Példa helyes formátumra: 192.168.0.10 192.168.0.200${normal}
    exit 1
fi

# Ellenőrizzük, hogy a DNS IP cím formátuma helyes-e
if [[ ! $domains_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo ${bold}${yellow}Hibás DNS IP cím formátum! Példa helyes formátumra: 192.168.0.254${normal}
    exit 1
fi

# Ha minden validáció sikeres, akkor a szkript folytatódik
echo ${bold}${yellow}Minden adat helyes formátumban van!${normal}

# Netplan konfigurációs fájl létrehozása
cat <<EOF | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
network:
    ethernets:
        enp0s3:
            dhcp4: true
        enp0s8:
            addresses: [$user_ip]
    version: 2
EOF

# Apply netplan settings
  echo ${bold}${yellow}Netplan configuration updating...${normal}
  sudo netplan apply
  echo ${bold}${yellow}Netplan settings succesfully updated!${normal}


# Installing packages
  echo ${bold}${yellow}Installing packages...${normal}  
  sudo apt install mc  lamp-server^ phpmyadmin w3m vsftpd openssh-server isc-dhcp-server postfix alpine popa3d samba cifs-utils bind9 bind9utils bind9-doc -y
cat <<EOF | sudo tee /etc/apt/sources.list.d/webmin.list > /dev/null
  # Repository for Webmin 
  deb http://download.webmin.com/download/repository sarge contrib 
EOF
    wget http://www.webmin.com/jcameron-key.asc 
    sudo apt-key add jcameron-key.asc
    sudo apt update  
    sudo apt install webmin -y

# Apply packages settings
  echo ${bold}${yellow}Updating packages settings...${normal}
  echo ${bold}Updating vsftpd.conf..${normal}
cat <<EOF | sudo tee /etc/vsftpd.conf > /dev/null
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
EOF

  sudo service vsftpd restart 
  
  echo ${bold}Updating dhcpd.conf..${normal}
cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf > /dev/null
default-lease-time 600; 
max-lease-time 7200; 
ddns-update-style none; 
authoritative; 
subnet $subnet_ip netmask $netmask_ip { 
  range $scope_ip; 
  option domain-name-servers $domains_ip; 
} 
EOF

  sudo service isc-dhcp-server restart
   
  echo ${bold}Updating isc-dhcp-server..${normal}
cat <<EOF | sudo tee /etc/default/isc-dhcp-server > /dev/null
# Defaults for isc-dhcp-server (sourced by /etc/init.d/isc-dhcp-server)

# Path to dhcpd's config file (default: /etc/dhcp/dhcpd.conf).
#DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
#DHCPDv6_CONF=/etc/dhcp/dhcpd6.conf

# Path to dhcpd's PID file (default: /var/run/dhcpd.pid).
#DHCPDv4_PID=/var/run/dhcpd.pid
#DHCPDv6_PID=/var/run/dhcpd6.pid

# Additional options to start dhcpd with.
#       Don't use options -cf or -pf here; use DHCPD_CONF/ DHCPD_PID instead
#OPTIONS=""

# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
#       Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACESv4="enp0s8"
INTERFACESv6=""
} 
EOF

  sudo mkdir /install 
  echo ${bold}Updating smb.conf..${normal}
cat <<EOF | sudo tee /etc/samba/smb.conf > /dev/null
[global]
   workgroup = WORKGROUP
   server string = %h server (Samba, Ubuntu)
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   usershare allow guests = yes
[printers]
   comment = All Printers
   browseable = no
   path = /var/tmp
   printable = yes
   guest ok = no
   read only = yes
   create mask = 0700
[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
[install] 
   path = /install 
   writeable = yes 
   comment = Itt vannak a telepitokeszletek
[homes]
   comment = Home Directories
   browseable = no
   writeable = yes
EOF

echo ${bold}Updating named.conf.local...${normal}
cat <<EOF | sudo tee /etc/bind/named.conf.local > /dev/null
zone "$domain_name" {
    type master;
    file "/etc/bind/db.$domain_name";
};
EOF

echo ${bold}Updating another bind config file...${normal}
cat <<EOF | sudo tee /etc/bind/db.$domain_name > /dev/null
\$TTL    604800
@       IN      SOA     ns.$domain_name. root.$domain_name. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.$domain_name.
ns      IN      A       $domains_ip
@       IN      A       $domains_ip
EOF


  echo ${bold}${yellow}Packages settings succesfully updated...${normal}

# Cleanup
    sudo rm /etc/sudoers.d/99-$USER
    sudo sed -i '140d' /etc/sudoers

# End of script
  echo ${bold}${yellow}Please reboot the system${normal}
  read -p "Szeretnéd újraindítani a rendszert? (y/n): " reboot_answer

if [[ "$reboot_answer" == "y" || "$reboot_answer" == "yes" || "$reboot_answer" == "Y" || "$reboot_answer" == "YES" ]]; then
    echo "Reboot 3..."
    echo "Reboot 2..."
    echo "Reboot 1..."
    echo "Rebooting..."
    reboot
else
    echo "The system can't be rebooted..."
fi

