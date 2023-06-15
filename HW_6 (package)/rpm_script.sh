#!/bin/bash

#Создание своего RPM пакета (nginx с openssl)

sudo -i
#Ставим необходимые пакеты
yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils openssl-devel zlib-devel pcre-devel gcc libtool perl-core openssl
#Переходим в директорию root
cd /root
#Скачиваем srpm nginx и openssl
wget https://nginx.org/packages/centos/7Client/SRPMS/nginx-1.22.1-1.el7.ngx.src.rpm
wget https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1s/openssl-1.1.1s.tar.gz
#Устанавливаем nginx
rpm -i nginx-1.22.1-1.el7.ngx.src.rpm
#Перемещаем openssl в rpmbuild и переходим в нее
mv /root/openssl-1.1.1s.tar.gz /root/rpmbuild/
cd /root/rpmbuild
#Распаковываем openssl
tar -xf /root/rpmbuild/openssl-1.1.1s.tar.gz
#Удаляем лишний архив
rm /root/rpmbuild/openssl-1.1.1s.tar.gz -f
#Ставим зависимости
yum-builddep /root/rpmbuild/SPECS/nginx.spec -y
#Кофигурируем spec через sed
sed -i 's/--with-debug/--with-openssl=\/root\/rpmbuild\/openssl-1.1.1s/g' /root/rpmbuild/SPECS/nginx.spec
#Собираем rpm
rpmbuild -bb /root/rpmbuild/SPECS/nginx.spec
#Ставим собранный nginx
yum localinstall -y /root/rpmbuild/RPMS/x86_64/nginx-1.22.1-1.el7.ngx.x86_64.rpm

#Создание своего репозитория

#Создаем директорию repo
mkdir /usr/share/nginx/html/repo
#Копируем туда свою nginx сборку
cp /root/rpmbuild/RPMS/x86_64/nginx-1.22.1-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/
#Также для примера качаем percona сразу в свой репозиторий
wget https://downloads.percona.com/downloads/percona-distribution-mysql-ps/percona-distribution-mysql-ps-8.0/binary/redhat/7/x86_64/percona-orchestrator-3.2.6-3.el7.x86_64.rpm?_gl=1*1y19a2t*_gcl_au*MTAzNzQyNTc5MC4xNjg2ODEyNzQ4 -O /usr/share/nginx/html/repo/percona-orchestrator-3.2.6-3.el7.x86_64.rpm
#Инициализируем репозиторий
createrepo /usr/share/nginx/html/repo/
#Добавляем в конфиг autoindex
sed -i '/index  index.html index.htm;/s/$/ \n\tautoindex on;/' /etc/nginx/conf.d/default.conf
#Перезагружаем конфигурацию nginx
nginx -s reload
#Добавляем репозиторий в /etc/yum.repos.d
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

yum clean all
