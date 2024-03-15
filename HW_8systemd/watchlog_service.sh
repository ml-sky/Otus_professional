#!/bin/bash

sudo -i
#Создаем сервис, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова. Файл и слово должны задаваться в /etc/sysconfig:

#Создаем файл конфигурации
cat >> /etc/sysconfig/watchlog << EOF

# Файл и слово которое мы будем мониторить
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF

#Создаем лог файл с ключевым словом ALERT
cat >> /var/log/watchlog.log << EOF
ALERT
EOF

#Создаем скрипт 
echo -e '#!/bin/bash\nWORD=$1\nLOG=$2\nDATE=`date`\nif grep $WORD $LOG &> /dev/null\nthen\nlogger "$DATE: I found word, Master!"\nelse\nexit 0\nfi' >> /opt/watchlog.sh

#Права на исполнение скрипта
chmod +x /opt/watchlog.sh

# Создаем unit для сервиса
echo -e '[Unit]\nDescription=My watchlog service\n[Service]\nType=oneshot\nEnvironmentFile=/etc/sysconfig/watchlog\nExecStart=/opt/watchlog.sh $WORD $LOG' >> /etc/systemd/system/watchlog.service

#Создаем юнит для таймера
cat >> /etc/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnActiveSec=1sec
OnUnitActiveSec=30
OnCalendar=*:*:0/30
AccuracySec=1us
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF

#Из epel установить spawn-fcgi и переписать init-скрипт на unit-файл. Имя сервиса должно также называться.

#Установка spawn-fcgi и необходимые для него пакеты:
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y

#Расскоментируем нужные параметры в spawn-fcgi
sed -i 's/#SOCKET/SOCKET/gi' /etc/sysconfig/spawn-fcgi && sed -i 's/#OPTIONS/OPTIONS/gi' /etc/sysconfig/spawn-fcgi

#Создаем unit
echo -e '[Unit]\nDescription=Spawn-fcgi startup service by Otus\nAfter=network.target\n[Service]\nType=simple\nPIDFile=/var/run/spawn-fcgi.pid\nEnvironmentFile=/etc/sysconfig/spawn-fcgi\nExecStart=/usr/bin/spawn-fcgi -n $OPTIONS\nKillMode=process\n[Install]\nWantedBy=multi-user.targe' >> /etc/systemd/system/spawn-fcgi.service

#Дополнить юнит-файл apache httpd возможностьб запустить несколько инстансов сервера с разными конфигами:

#Создание шаблонов в конфигурации окружения
echo -e '[Unit]\nDescription=The Apache HTTP Server\nAfter=network.target remote-fs.target nss-lookup.target\nDocumentation=man:httpd(8)\nDocumentation=man:apachectl(8)\n[Service]\nType=notify\nEnvironmentFile=/etc/sysconfig/httpd-%I\nExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND\nExecReload=/usr/sbin/httpd $OPTIONS -k graceful\nExecStop=/bin/kill -WINCH ${MAINPID}\nKillSignal=SIGCONT\nPrivateTmp=true\n[Install]\nWantedBy=multi-user.target' >> /etc/systemd/system/httpd@.service

echo -e 'OPTIONS=-f conf/first.conf' >> /etc/sysconfig/httpd-first
echo -e 'OPTIONS=-f conf/second.conf' >> /etc/sysconfig/httpd-second

#Создаем 2 конфигурации в httpd
cd /etc/httpd/conf
mv httpd.conf first.conf
cp first.conf second.conf

#Меняем порт и PID во второй конфигурации
sed -i 's/Listen 80/Listen 8080/gi' /etc/httpd/conf/second.conf
sed -i '42i\PidFile /var/run/httpd-second.pid' /etc/httpd/conf/second.conf





