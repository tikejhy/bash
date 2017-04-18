#!/bin/bash

#Remove old php
yum remove php*

#We need phpunit only if its devweb
if [[ `hostname -s` == "devweb1" ]]; then 

	yum install -y php-phpunit-PHP-CodeCoverage php-phpunit-PHPUnit-MockObject php-phpunit-comparator php-phpunit-PHP-Invoker php-phpunit-exporter php-phpunit-PHP-Timer php-phpunit-diff php-phpunit-Text-Template php-phpunit-File-Iterator php-phpunit-PHP-TokenStream php-phpunit-environment php-phpunit-Version

fi

#Install all dependency and new php package
yum install -y php71 php71-php php71-php-pecl-memcached php71-php-pecl-redis php71-php-pecl-igbinary php71-php-pecl-geoip
yum install -y php71-php-pear php71-php-cli php71-php-process php71-php-xml php71-php-pecl-msgpack php71-php-mbstring
yum install -y php71-php-doctrine-instantiator php71-php-phpunit-Text-Template php71-php-soap php71-php-tidy php71-php-bcmath
yum install -y php71-php-fpm php71-php-gd php71-php-opcache php71-php-pecl-apcu php71-php-mysqlnd php71-php-pdo php71-php-pecl-jsonc
yum install -y php71-php-pecl-zip php71-php-common php71-php-bcmath php71-php-pecl-geoip php71-php-pecl-zip php71-php-pgsql


#Remove old php-fpm and its config and php file as php56
rm -f /etc/init.d/php-fpm
mv /etc/opt/remi/php71/php-fpm.conf /etc/opt/remi/php71/php-fpm.conf.bak
mv /etc/opt/remi/php71/php-fpm.d/www.conf /etc/opt/remi/php71/php-fpm.d/www.conf.bak
mv /usr/bin/php /usr/bin/php56

#Symlink php71 as php so we run php71 as main binary
ln -sfn /usr/bin/php71 /usr/bin/php
#init file for php-fpm to be called as php-fpm
ln -sfn /etc/init.d/php71-php-fpm /etc/init.d/php-fpm
#Copy php-fpm configuration 
cp /etc/php-fpm.conf.rpmsave /etc/opt/remi/php71/php-fpm.conf
cp /etc/php-fpm.d/www.conf.rpmsave /etc/opt/remi/php71/php-fpm.d/www.conf

#if include is pointing at this path;
cp /etc/php-fpm.d/www.conf.rpmsave cp /etc/php-fpm.d/www.conf

#lets fix init file and conf
sed -i 's_/etc/php-fpm.d_\/etc/opt/remi/php71/php-fpm.d_g' /etc/opt/remi/php71/php-fpm.conf
sed -i "/rm -f ${lockfile} ${pidfile}/c\rm -f ${lockfile} ${pidfile}; rm -f /tmp/php5-fpm.sock" /etc/init.d/php71-php-fpm


/etc/init.d/php-fpm restart
/etc/init.d/nginx restart
