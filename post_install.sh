#!/bin/sh

# Set Global
export LC_ALL=C
FILE_NAME="clonedeploy-freenas-1.4.0.tar.gz"
EXPECTED_HASH="04858b3079e05a954b283da126dd31d557f4c419d4fc05801b13cbd3db1e36d59"
SQL_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
RAND_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)


# make clonedeploy startup script executable
chmod +x /usr/local/etc/rc.d/clonedeploy 


# Enable the services
sysrc -f /etc/rc.conf nginx_enable="YES" 
sysrc -f /etc/rc.conf mysql_enable="YES" 
sysrc -f /etc/rc.conf clonedeploy_enable="YES" 


# Start mariadb, others are started at the end
service mysql-server start 


# download clonedeploy, try 2 mirrors
if ! wget -q "https://sourceforge.net/projects/clonedeploy/files/CloneDeploy 1.4.0/${FILE_NAME}"; then
  echo "Could not retrieve CloneDeploy from Sourceforge, trying clonedeploy.org" 2>log
  if ! wget -q "http://files.clonedeploy.org/${FILE_NAME}"; then
    echo "Could not retrieve CloneDeploy from clonedeploy.org, exiting." 2>log
	exit 1
  fi
fi


# verify hash
ACTUAL_HASH=`sha256 /${FILE_NAME} | awk '{print $4}'`
if [ ${EXPECTED_HASH} != ${ACTUAL_HASH} ]; then
  echo "File hash mismatch." 2>log
  echo "Actual: ${ACTUAL_HASH}" 2>log
  echo "Expected: ${EXPECTED_HASH}" 2>log
  echo "Exiting." 2>log
  exit 1
fi


# install web application
tar xvzf ${FILE_NAME} 
cd clonedeploy 
mkdir /usr/local/www/nginx/clonedeploy 
cp -r frontend /usr/local/www/nginx/clonedeploy 
cp -r api /usr/local/www/nginx/clonedeploy 
mkdir /.mono 
mkdir /cd_dp 
mkdir /cd_dp/images 
mkdir /cd_dp/resources 
sed -i "" "s/xx_marker1_xx/$SQL_PASS/" /usr/local/www/nginx/clonedeploy/api/Web.config 
sed -i "" "s/xx_marker2_xx/$RAND_KEY/" /usr/local/www/nginx/clonedeploy/api/Web.config 
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
mysqladmin -u root password ${SQL_PASS} 
mysql -u root --password=${SQL_PASS} clonedeploy < /clonedeploy/cd.sql 


# Set permissions
chown -R www:www /tftpboot /cd_dp /usr/local/www/nginx/clonedeploy /.mono /cd_dp 
chmod 1777 /tmp 


# make udpcast
cd /usr/ports/net/udpcast
make
make install 


# Restart services
service mysql-server restart 
service nginx start 
service clonedeploy start 

