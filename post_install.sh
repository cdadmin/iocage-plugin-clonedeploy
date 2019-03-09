#!/bin/sh

# Set Global
export LC_ALL=C
POST_INSTALL_LOG="post_install.log"
echo "Starting Post Install" &> POST_INSTALL_LOG
FILE_NAME="clonedeploy-freenas-1.4.0.tar.gz"
EXPECTED_HASH=ebcb65f41c6697654d92a968d1b4b21afc36f5cf542d076886b80992164a8afd
SQL_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
RAND_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)


# make clonedeploy startup script executable
echo "Setting executable on clonedeploy startup script" &>> POST_INSTALL_LOG
chmod +x /usr/local/etc/rc.d/clonedeploy &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG


# Enable the services
echo "Enabling Services" &>> POST_INSTALL_LOG
sysrc -f /etc/rc.conf nginx_enable="YES" &>> POST_INSTALL_LOG
sysrc -f /etc/rc.conf mysql_enable="YES" &>> POST_INSTALL_LOG
sysrc -f /etc/rc.conf clonedeploy_enable="YES" &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG


# Start mariadb, others are started at the end
echo "Starting Mariadb" &>> POST_INSTALL_LOG
service mysql-server start &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG 


# download clonedeploy, try 2 mirrors
echo "Downloading ${FILE_NAME}" &>> POST_INSTALL_LOG
if ! wget -q "https://sourceforge.net/projects/clonedeploy/files/CloneDeploy 1.4.0/${FILE_NAME}"; then
  echo "Could not retrieve CloneDeploy from Sourceforge, attempting download from clonedeploy.org" &>> POST_INSTALL_LOG
  if ! wget -q "http://files.clonedeploy.org/${FILE_NAME}"; then
    echo "Could not retrieve CloneDeploy from clonedeploy.org, exiting." &>> POST_INSTALL_LOG
	exit 1
  fi
fi
echo "..... Complete" &>> POST_INSTALL_LOG


# verify hash
echo "Verifying ${FILE_NAME} Hash" &>> POST_INSTALL_LOG
ACTUAL_HASH=`sha256 {$FILE_NAME} | awk '{print $4}'`
echo "Actual Hash: ${ACTUAL_HASH}" &>> POST_INSTALL_LOG
echo "Expected Hash: ${EXPECTED_HASH}" &>> POST_INSTALL_LOG
if [ ${EXPECTED_HASH} != ${ACTUAL_HASH} ]; then
  echo "File Hash Mismatch.  Exiting." &>> POST_INSTALL_LOG
  exit 1
fi
echo "..... Complete" &>> POST_INSTALL_LOG


# install web application
echo "Installing Web Application" &>> POST_INSTALL_LOG
tar xvzf ${FILE_NAME} &>> POST_INSTALL_LOG
cd clonedeploy &>> POST_INSTALL_LOG
mkdir /usr/local/www/nginx/clonedeploy &>> POST_INSTALL_LOG
cp -r frontend /usr/local/www/nginx/clonedeploy &>> POST_INSTALL_LOG
cp -r api /usr/local/www/nginx/clonedeploy &>> POST_INSTALL_LOG
mkdir /.mono &>> POST_INSTALL_LOG
mkdir /cd_dp &>> POST_INSTALL_LOG
mkdir /cd_dp/images &>> POST_INSTALL_LOG
mkdir /cd_dp/resources &>> POST_INSTALL_LOG
sed -i "" "s/xx_marker1_xx/$SQL_PASS/" /usr/local/www/nginx/clonedeploy/api/Web.config &>> POST_INSTALL_LOG
sed -i "" "s/xx_marker2_xx/$RAND_KEY/" /usr/local/www/nginx/clonedeploy/api/Web.config &>> POST_INSTALL_LOG
echo "Local,http://localhost/" > /usr/local/www/nginx/clonedeploy/frontend/serverlist.csv &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG


# Setup Tftp
echo "Copying Tftp files" &>> POST_INSTALL_LOG
cp -r tftpboot / &>> POST_INSTALL_LOG
ln -s ../../images /tftpboot/proxy/bios/images &>> POST_INSTALL_LOG
ln -s ../../images /tftpboot/proxy/efi32/images &>> POST_INSTALL_LOG
ln -s ../../images /tftpboot/proxy/efi64/images &>> POST_INSTALL_LOG
ln -s ../../kernels /tftpboot/proxy/bios/kernels &>> POST_INSTALL_LOG
ln -s ../../kernels /tftpboot/proxy/efi32/kernels &>> POST_INSTALL_LOG
ln -s ../../kernels /tftpboot/proxy/efi64/kernels &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG


#Setup Database
echo "Setting up database" &>> POST_INSTALL_LOG
mysqladmin -u root create clonedeploy &>> POST_INSTALL_LOG
mysqladmin -u root password ${SQL_PASS} &>> POST_INSTALL_LOG
mysql -u root --password=${SQL_PASS} clonedeploy < /clonedeploy/cd.sql &>> POST_INSTALL_LOG
#mysql -u root --password=${SQL_PASS} -e  "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' identified by '${SQL_PASS}';flush privileges;"
echo "..... Complete" &>> POST_INSTALL_LOG


# Set permissions
echo "Setting Permissions" &>> POST_INSTALL_LOG
chown -R www:www /tftpboot /cd_dp /usr/local/www/nginx/clonedeploy /.mono /cd_dp &>> POST_INSTALL_LOG
chmod 1777 /tmp &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG


# make udpcast
echo "Installing Udpcast" &>> POST_INSTALL_LOG
cd /usr/ports/net/udpcast
make
make install &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG


# Restart services
echo "Starting services" &>> POST_INSTALL_LOG
service mysql-server restart &>> POST_INSTALL_LOG
service nginx start &>> POST_INSTALL_LOG
service clonedeploy start &>> POST_INSTALL_LOG
echo "..... Complete" &>> POST_INSTALL_LOG

mono -V &>> POST_INSTALL_LOG
ngingx -v &>> POST_INSTALL_LOG
mysql -V &>> POST_INSTALL_LOG
pkg list | grep ap24-mod_mono | head -n1 &>> POST_INSTALL_LOG
echo "Post Install Complete" &>> POST_INSTALL_LOG