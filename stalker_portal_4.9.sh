#!/bin/bash

echo -e " \e[32mUpdateing system\e[0m"
sleep 2
apt-get update -y
apt-get upgrade -y
apt-get install net-tools -y 

VERSION="4.9.35"
TIME_ZONE="Europe/Amsterdam" #
mysql_root_password="test123456"
repository="https://manner-rising-st-voting.trycloudflare.com/stalker"

# SET LOCALE TO UTF-8
function setLocale {
	echo -e " \e[32mSetting locales\e[0m"
	locale-gen en_US.UTF-8  >> /dev/null 2>&1
	export LANG="en_US.UTF-8" >> /dev/null 2>&1
	echo -e " \e[32mDone.\e[0m"
}

# TWEAK SYSTEM VALUES
function tweakSystem {
	echo -ne "\e[32mTweaking system"
	echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "fs.file-max = 327680" >> /etc/sysctl.conf
	echo "kernel.core_uses_pid = 1" >> /etc/sysctl.conf
	echo "kernel.core_pattern = /var/crash/core-%e-%s-%u-%g-%p-%t" >> /etc/sysctl.conf
	echo "fs.suid_dumpable = 2" >> /etc/sysctl.conf
	sysctl -p >> /dev/null 2>&1
	echo -e " \e[32mDone.\e[0m"
}

setLocale;
tweakSystem;

sleep 3

add-apt-repository ppa:ondrej/php -y

echo -e " \e[32mInstall required packages\e[0m"
sleep 3
apt-get install nginx nginx-extras -y 
/etc/init.d/nginx stop
sleep 1
apt-get install apache2 -y
/etc/init.d/apache2 stop
sleep 1

apt-get -y install php5.6-geoip php5.6-intl php5.6-tidy php5.6-igbinary php5.6-msgpack php5.6-mcrypt php5.6-mbstring php5.6-zip memcached php5.6 php5.6-xml php5.6-gettext php5.6-soap php5.6-mysql php-pear nodejs libapache2-mod-php5.6 php5.6-curl php5.6-imagick php5.6-sqlite3 unzip
update-alternatives --set php /usr/bin/php5.6

sleep 2

echo -e " \e[32mInstalling phing\e[0m"
sleep 3
pear channel-discover pear.phing.info
#pear install -Z phing/phing-2.15.2
pear install --alldeps phing/phing-2.15.2

echo -e " \e[32mSet the Server Timezone to EDT\e[0m"
sleep 3
timedatectl set-timezone $TIME_ZONE
dpkg-reconfigure -f noninteractive tzdata


echo -e " \e[32mInstalling mysql server\e[0m"
sleep 3
export DEBIAN_FRONTEND="noninteractive"
echo "mysql-server mysql-server/root_password password $mysql_root_password" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root_password" | sudo debconf-set-selections
apt-get install -y mysql-server
sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
mysql -uroot -p$mysql_root_password -e "USE mysql; UPDATE user SET Host='%' WHERE User='root' AND Host='localhost'; DELETE FROM user WHERE Host != '%' AND User='root'; FLUSH PRIVILEGES;"
mysql -uroot -p$mysql_root_password -e "create database stalker_db;"
mysql -uroot -p$mysql_root_password -e "ALTER USER root IDENTIFIED WITH mysql_native_password BY '"$mysql_root_password"';"
mysql -uroot -p$mysql_root_password -e "CREATE USER stalker IDENTIFIED BY '1';"
mysql -uroot -p$mysql_root_password -e "GRANT ALL ON *.* TO stalker WITH GRANT OPTION;"
mysql -ustalker -p1 -e "ALTER USER stalker IDENTIFIED WITH mysql_native_password BY '1';"


echo 'sql_mode=""' >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf
sed -i 's/max_allowed_packet[[:space:]]= 16/max_allowed_packet      = 32/' /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart

echo -e " \e[32mInstalling Stalker Portal $VERSION \e[0m"
sleep 3
cd /var/www/html/
wget $repository/stalker_portal_$VERSION.zip
unzip stalker_portal_$VERSION.zip
mv stalker_portal-4.9.35 stalker_portal
rm -rf *.zip

#Patch Support MAG420/MAG322/MAG324 ON THE PORTAL VERSION 4.9.X
cd /var/www/html/stalker_portal
wget $repository/support.patch
patch -p1 < support.patch
sleep 1

sed -i "s/'modified!=' => ''/'modified!=' => time()/" /var/www/html/stalker_portal/server/administrator/add_itv.php
sed -i "44i\    this.ntp_wait_time = 0;\n" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "46i\    this.clock_formats = {'12h': '{2}:{1} {3}', '24h': '{0}:{1}'};\n" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "s/main_menu.time.innerHTML = get_word('time_format')/main_menu.time.innerHTML = stb.clock_formats[stb.profile.clock_format]/" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "s/main_menu.date.innerHTML = get_word('date_format')/main_menu.date.innerHTML = stb.clock_formats[stb.profile.clock_format]/" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "s/stb.player.info.clock.innerHTML = get_word('time_format')/stb.player.info.clock.innerHTML = stb.clock_formats[stb.profile.clock_format]/" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "s/module.tv.clock_box.innerHTML = get_word('time_format')/module.tv.clock_box.innerHTML = stb.clock_formats[stb.profile.clock_format]/" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "685i\                if (\!this.profile.clock_format) {" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "686i\                    this.profile.clock_format = (get_word('time_format') && this.clock_formats[get_word('time_format')]) ? this.clock_formats[get_word('time_format')]: '24h';" /var/www/html/stalker_portal/c/xpcom.common.js
sed -i "687i\                }\n" /var/www/html/stalker_portal/c/xpcom.common.js

sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php/5.6/apache2/php.ini
ln -s /etc/php/5.6/mods-available/mcrypt.ini /etc/php/8.0/mods-available/
phpenmod mcrypt
a2enmod rewrite

cd /etc/apache2/sites-enabled/
rm -rf *
wget $repository/000-default.conf
cd /etc/apache2/
rm -rf ports.conf
wget $repository/ports.conf
cd /etc/nginx/sites-available/
rm -rf default
wget $repository/default
/etc/init.d/apache2 restart
/etc/init.d/nginx restart

cd /var/www/html/stalker_portal/server
wget $repository/custom.ini

cd /var/www/html/stalker_portal/server
sed -i -r 's|^(default_timezone =).*|\1'" $TIME_ZONE"'|' config.ini
sed -i -r 's/^(default_locale =).*/\1 en_US.utf8/' config.ini

cd /var/www/html/stalker_portal/deploy
sed -i 's/composer.phar install/composer.phar install --version=1.9.1/g' build.xml
sed -i 's/apt-get -y install php-soap php5-intl php-gettext php5-memcache php5-curl php5-mysql php5-tidy php5-imagick php5-geoip curl/apt-get -y install php5.6-soap php5.6-intl php5.6-gettext php5.6-memcache php5.6-curl php5.6-mysql php5.6-tidy php5.6-imagick php5.6-geoip curl/g' build.xml
sudo phing
sleep 1

echo -e " \e[32m-------------------------------------------------------------------"
echo -e " \e[0mInstall Complete !"
echo ""
echo -e " \e[0mDefault username is: \e[32madmin"
echo -e " \e[0mDefault password is: \e[32m1"
echo ""
echo -e " \e[0mPORTAL WAN : \e[32mhttp://`wget -qO- http://ipecho.net/plain | xargs echo`/stalker_portal/server/administrator"
echo -e " \e[0mPORTAL LAN : \e[32mhttp://`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`/stalker_portal/server/administrator"
echo -e " \e[0mMysql User : \e[32mroot"
echo -e " \e[0mMySQL Pass : \e[32m$mysql_root_password"
echo ""
echo -e " \e[0mChange admin panel password through the terminal :"
echo -e " \e[32mmysql -u root -p"
echo -e " \e[32muse stalker_db;"
echo -e " \e[32mupdate administrators set pass=MD5('new_password_here') where login='admin';"
echo -e " \e[32mquit;"
echo -e " \e[0mLogout from web panel and Login with new password."
echo ""
echo -e " \e[0mRemove all test channels from the database through the terminal :"
echo -e " \e[32mmysql -u root -p stalker_db"
echo -e " \e[32mtruncate ch_links;"
echo -e " \e[32mtruncate itv;"
echo -e " \e[32mquit;"
echo -e " \e[32m--------------------------------------------------------------------\e[0m"
