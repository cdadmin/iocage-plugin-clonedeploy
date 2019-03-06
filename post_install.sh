#!/bin/sh

# Enable the services
sysrc -f /etc/rc.conf apache24_enable="YES"
sysrc -f /etc/rc.conf mysql_enable="YES"
sysrc -f /etc/rc.conf samba_server_enable="YES"
sysrc -f /etc/rc.conf tftpd_enable="YES"

# Start the services
service mysql-server start 2>/dev/null
service apache24 start 2>/dev/null
service samba_server start 2> /dev/null
service tftpd start 2> /dev/null

# Set Global
export LC_ALL=C
sql_pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
rand_key=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

wget "https://sourceforge.net/projects/clonedeploy/files/CloneDeploy 1.4.0/clonedeploy-1.4.0.tar.gz"
tar xvzf clonedeploy-1.4.0.tar.gz
cd clonedeploy
mkdir /usr/local/www/apache24/data/clonedeploy
cp -r frontend /usr/local/www/apache24/data/clonedeploy
cp -r api /usr/local/www/apache24/data/clonedeploy
mkdir /.mono
sed -i "s/xx_marker1_xx/$sql_pass/" /usr/local/www/apache24/data/clonedeploy/api/Web.config
sed -i "s/xx_marker2_xx/$rand_key/" /usr/local/www/apache24/data/clonedeploy/api/Web.config

# Setup Tftp
cp -r tftpboot /
ln -s ../../images /tftpboot/proxy/bios/images
ln -s ../../images /tftpboot/proxy/efi32/images
ln -s ../../images /tftpboot/proxy/efi64/images
ln -s ../../kernels /tftpboot/proxy/bios/kernels
ln -s ../../kernels /tftpboot/proxy/efi32/kernels
ln -s ../../kernels /tftpboot/proxy/efi64/kernels

#Setup Database
mysqladmin -u root create clonedeploy
mysqladmin -u root password ${sql_pass}
mysql -u root --password=${sql_pass} clonedeploy < /root/clonedeploy/cd.sql
mysql -u root --password=${sql_pass} -e  "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' identified by '${sql_pass}';flush privileges;"

#Setup SMB
mkdir -p /cd_dp/images
mkdir /cd_dp/resources

#echo "[cd_share]" >> /usr/local/etc/smb4.conf
#echo "path = /cd_dp" >> /usr/local/etc/smb4.conf
#echo "valid users = @cdsharewriters, cd_share_ro" >> /usr/local/etc/smb4.conf
#echo "create mask = 02775" >> /usr/local/etc/smb4.conf
#echo "directory mask = 02775" >> /usr/local/etc/smb4.conf
#echo "guest ok = no" >> /usr/local/etc/smb4.conf
#echo "writable = yes" >> /usr/local/etc/smb4.conf
#echo "browsable = yes" >> /usr/local/etc/smb4.conf
#echo "read list = @cdsharewriters, cd_share_ro" >> /usr/local/etc/smb4.conf
#echo "write list = @cdsharewriters" >> /usr/local/etc/smb4.conf
#echo "force create mode = 02775" >> /usr/local/etc/smb4.conf
#echo "force directory mode = 02775" >> /usr/local/etc/smb4.conf
#echo "force group = +cdsharewriters" >> /usr/local/etc/smb4.conf
pw groupadd cdsharewriters
pw useradd cd_share_ro
pw useradd cd_share_rw -G cdsharewriters
pw usermod www -G cdsharewriters
printf "read\nread\n" | smbpasswd -a cd_share_ro
printf "write\nwrite\n" | smbpasswd -a cd_share_rw

# Set permissions
chown -R www:www /tftpboot /cd_dp /usr/local/www/apache24/data/clonedeploy /.mono
chmod 1777 /tmp
chown -R www:cdsharewriters /cd_dp
chmod -R 2775 /cd_dp

# Restart services
service mysql-server restart 2>/dev/null
service apache24 restart 2>/dev/null
service samba_server restart 2> /dev/null
service tftpd restart 2> /dev/null