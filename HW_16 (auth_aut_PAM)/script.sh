#Скрипт на ограничение доступа по группе с помощью pam_script

#!/bin/bash
#
yum install -y epel-release
yum install -y pam_script
useradd otusadm
useradd otus
groupadd admin
usermod -a -G admin otusadm
echo "otusadm:Otus2024" | chpasswd
echo "otus:Otus2024" | chpasswd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i "2i auth  required  pam_script.so"  /etc/pam.d/sshd
#Проверяем состоит ли пользователь в группе admin и если да то пускаем его. 
#Если он не состоит в этой группе то срабатывает проверка на то, какой сейчас день недели, если он больше 5 (6 и 7 выходные), то не пускаем.
cat <<'EOT' > /etc/pam_script
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi
EOT
chmod +x /etc/pam_script
systemctl restart sshd
