#!/bin/bash

#Переходим в root
sudo -i

#Устанавливаем утилиты nfs
yum install nfs-utils -y

#Включаем firewall и разрешаем доступы к сервисам nfs
systemctl enable firewalld --now 
firewall-cmd --add-service="nfs3" --add-service="rpc-bind" --add-service="mountd" --permanent 
firewall-cmd --reload

#Включаем nfs
systemctl enable nfs --now 

#Создаем директорию для экспорта
mkdir -p /srv/share/upload_otus
chown -R nfsnobody:nfsnobody /srv/share
chmod 0777 /srv/share/upload_otus

#Структура для экспорта
cat << EOF > /etc/exports
/srv/share 192.168.50.11/32(rw,sync,root_squash) 
EOF

#Экспортируем
exportfs -r

#Создаем тестовый файл для проверки
touch /srv/share/upload_otus/test_nfs

