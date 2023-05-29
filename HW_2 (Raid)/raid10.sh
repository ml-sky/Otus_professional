#!/bin/bash

#Установка нужных утилит
sudo yum install -y mdadm smartmontools hdparm gdisk

#Зануление суперблоков
sudo mdadm --zero-superblock --force /dev/sd{b,c,d,e}

#Создание Raid 10
sudo mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{b,c,d,e}

#Создание конфигурационного файла
sudo mkdir /etc/mdadm
sudo touch /etc/mdadm/mdadm.conf
sudo chmod 666 /etc/mdadm/mdadm.conf
sudo echo «DEVICE partitions» > /etc/mdadm/mdadm.conf
sudo mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf

#Создание GPT раздела с партициями
sudo parted -s /dev/md0 mklabel gpt
sudo parted /dev/md0 mkpart primary ext4 0% 20%
sudo parted /dev/md0 mkpart primary ext4 20% 40%
sudo parted /dev/md0 mkpart primary ext4 40% 60%
sudo parted /dev/md0 mkpart primary ext4 60% 80%
sudo parted /dev/md0 mkpart primary ext4 80% 100%

#Создание файловой системы на разделах
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
sudo mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do sudo mount /dev/md0p$i /raid/part$i; done

#Примонтирование после перезагрузки
sudo sed -i '10i\/dev/md0p1        /raid/part1    ext4    defaults    1 2' /etc/fstab
sudo sed -i '11i\/dev/md0p2        /raid/part2    ext4    defaults    1 2' /etc/fstab
sudo sed -i '12i\/dev/md0p3        /raid/part3    ext4    defaults    1 2' /etc/fstab
sudo sed -i '13i\/dev/md0p4        /raid/part4    ext4    defaults    1 2' /etc/fstab
sudo sed -i '14i\/dev/md0p5        /raid/part5    ext4    defaults    1 2' /etc/fstab