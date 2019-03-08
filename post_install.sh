#!/bin/sh
chmod +x /usr/local/etc/rc.d/clonedeploy

# Enable the services
sysrc -f /etc/rc.conf nginx_enable="YES"
sysrc -f /etc/rc.conf mysql_enable="YES"
sysrc -f /etc/rc.conf clonedeploy_enable="YES"

# Start the services
service mysql-server start 

# Set Global
export LC_ALL=C
sql_pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
rand_key=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

wget "https://sourceforge.net/projects/clonedeploy/files/CloneDeploy 1.4.0/clonedeploy-1.4.0.tar.gz"
tar xvzf clonedeploy-1.4.0.tar.gz
cd clonedeploy
mkdir /usr/local/www/nginx/clonedeploy
cp -r frontend /usr/local/www/nginx/clonedeploy
cp -r api /usr/local/www/nginx/clonedeploy
mkdir /.mono
sed -i "" "s/xx_marker1_xx/$sql_pass/" /usr/local/www/nginx/clonedeploy/api/Web.config
sed -i "" "s/xx_marker2_xx/$rand_key/" /usr/local/www/nginx/clonedeploy/api/Web.config
echo "Local,http://localhost/" > /usr/local/www/nginx/clonedeploy/frontend/serverlist.csv

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
mysql -u root --password=${sql_pass} clonedeploy < /clonedeploy/cd.sql
mysql -u root --password=${sql_pass} -e  "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' identified by '${sql_pass}';flush privileges;"

# Set permissions
chown -R www:www /tftpboot /cd_dp /usr/local/www/nginx/clonedeploy /.mono
chmod 1777 /tmp

# make udpcast
cd /usr/ports/net/udpcast
make
make install

# Restart services
service mysql-server restart 2>/dev/null
service nginx start 2>/dev/null
service clonedeploy start 2>/dev/null