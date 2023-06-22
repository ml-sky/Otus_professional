1.Уменьшить том под / до 8G т.к у нас CentOS 7 а xfs из "коробки" нельзя уменьшить не пересоздав раздел, то мы перенесем / на другой (временный) том , а потом уменьшив старый - перенесем корень обратно. 
	1.1 Переносим / на другой том
	
		#Устанавливаем необходимые для работы инструменты
		yum install nano xfsdump
		
		[root@lvm ~]# lsblk
			NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
			sda                       8:0    0   40G  0 disk 
			├─sda1                    8:1    0    1M  0 part 
			├─sda2                    8:2    0    1G  0 part /boot
			└─sda3                    8:3    0   39G  0 part 
				├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
				└─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
			sdb                       8:16   0   10G  0 disk 
			sdc                       8:32   0    2G  0 disk 
			sdd                       8:48   0    1G  0 disk 
			sde                       8:64   0    1G  0 disk 
		
		#Готовим временный том для / раздела:
		pvcreate /dev/sdb
		vgcreate vg_root /dev/sdb
		lvcreate -n lv_root -l +100%FREE /dev/vg_root
		
		#Создаем файловую систему
		mkfs.xfs /dev/vg_root/lv_root
		
		#Монтируем 
		mount /dev/vg_root/lv_root /mnt
		
		#Через xfsdump скопируем все данные с / раздела в /mnt
		xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
		
		#Далее необходимо переконфигурировать grub (проще сделать через цикл):
		for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
		chroot /mnt/
		grub2-mkconfig -o /boot/grub2/grub.cfg
		
		#Далее обновляем образ initrd:
		cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
		
		#Также чтобы при загрузке был смонтирован нужный root далее необходимо нужно в файле /boot/grub2/grub.cfg  заменить rd.lvm.lv=VolGroup00/LogVol00 на rd.lvm.lv=vg_root/lv_root
		#И меняем в файле /etc/fstab монтирование корня
		sed -i 's/\/dev\/mapper\/VolGroup00-LogVol00/\/dev\/mapper\/vg_root-lv_root/gi' /etc/fstab
		#Выходим из chroot командой exit. Далее перезагружаем reboot
		
		#Проверяем что том для корня сменился
		[root@lvm ~]# lsblk
			NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
			sda                       8:0    0   40G  0 disk
			├─sda1                    8:1    0    1M  0 part
			├─sda2                    8:2    0    1G  0 part /boot
			└─sda3                    8:3    0   39G  0 part
				├─VolGroup00-LogVol00 253:1    0 37.5G  0 lvm
				└─VolGroup00-LogVol01 253:2    0  1.5G  0 lvm  [SWAP]
			sdb                       8:16   0   10G  0 disk
			└─vg_root-lv_root       253:0    0   10G  0 lvm  /
			sdc                       8:32   0    2G  0 disk
			sdd                       8:48   0    1G  0 disk
			sde                       8:64   0    1G  0 disk
	
	1.2 Меняем размер старой vg и возвращаем туда корень
		
		#Удаляем старый LV
		lvremove /dev/VolGroup00/LogVol00
		
		#Создаем новый (со старым назвением) том с размером 8 ГБ в нашей старой volume group
		lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
		
		#Создаем на нем фс
		mkfs.xfs /dev/VolGroup00/LogVol00
		
		#Монтируем в /mnt
		mount /dev/VolGroup00/LogVol00 /mnt
		
		#Также как и в первый раз копируем xfsdump с нового / в mnt
		xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
		
		#Переконфигурируем grub и обновляем initrd как и в начале (пункт 1.1)
		for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
		chroot /mnt/
		grub2-mkconfig -o /boot/grub2/grub.cfg
		cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
		
		#Меняем в /etc/fstab обратно
		sed -i 's/\/dev\/mapper\/vg_root-lv_root/\/dev\/mapper\/VolGroup00-LogVol00/gi' /etc/fstab
		
		#Выходим из chroot командой exit. Далее reboot
		
		#Смотрим результат:
		[root@lvm ~]# lsblk
			NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
			sda                       8:0    0   40G  0 disk
			├─sda1                    8:1    0    1M  0 part
			├─sda2                    8:2    0    1G  0 part /boot
			└─sda3                    8:3    0   39G  0 part
				├─VolGroup00-LogVol00 253:0    0    8G  0 lvm  /
				└─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
			sdb                       8:16   0   10G  0 disk
			└─vg_root-lv_root       253:2    0   10G  0 lvm
			sdc                       8:32   0    2G  0 disk
			sdd                       8:48   0    1G  0 disk
			sde                       8:64   0    1G  0 disk
		
		#Можно также удалить временную vg под /
		lvremove /dev/vg_root/lv_root
		vgremove /dev/vg_root
		pvremove /dev/sdb

2.Выделить том под /var (/var - сделать в mirror)

	#Сначало создаем зеркало
	pvcreate /dev/sdc /dev/sdd
	vgcreate vg_var /dev/sdc /dev/sdd
	lvcreate -L 950M -m1 -n lv_var vg_var

	#Проверяем:
	[root@lvm ~]# lsblk
			NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
			sda                        8:0    0   40G  0 disk
			├─sda1                     8:1    0    1M  0 part
			├─sda2                     8:2    0    1G  0 part /boot
			└─sda3                     8:3    0   39G  0 part
				├─VolGroup00-LogVol00  253:0    0    8G  0 lvm  /
				└─VolGroup00-LogVol01  253:1    0  1.5G  0 lvm  [SWAP]
			sdb                        8:16   0   10G  0 disk
			└─vg_root-lv_root        253:2    0   10G  0 lvm
			sdc                        8:32   0    2G  0 disk
			├─vg_var-lv_var_rmeta_0  253:3    0    4M  0 lvm
			│ └─vg_var-lv_var        253:7    0  952M  0 lvm
			└─vg_var-lv_var_rimage_0 253:4    0  952M  0 lvm
			  └─vg_var-lv_var        253:7    0  952M  0 lvm
			sdd                        8:48   0    1G  0 disk
			├─vg_var-lv_var_rmeta_1  253:5    0    4M  0 lvm
			│ └─vg_var-lv_var        253:7    0  952M  0 lvm
			└─vg_var-lv_var_rimage_1 253:6    0  952M  0 lvm
			  └─vg_var-lv_var        253:7    0  952M  0 lvm
			sde                        8:64   0    1G  0 disk
			
	#Создаем ФС
	mkfs.ext4 /dev/vg_var/lv_var
	#Монтируем /mnt
	mount /dev/vg_var/lv_var /mnt
	#Копируем все содержимое /var
	cp -aR /var/* /mnt/
	
	#Сохраним содержимое текущего var в /tmp
	mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
	
	#Монтируем новый var в каталог /var
	umount /mnt
	mount /dev/vg_var/lv_var /var
	
	#Правим fstab для автоматического монтирования /var (Можно вручную):
	echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
	
	#Перезапускаем и смотрим:
	[root@lvm ~]# lsblk
		NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
		sda                        8:0    0   40G  0 disk
		├─sda1                     8:1    0    1M  0 part
		├─sda2                     8:2    0    1G  0 part /boot
		└─sda3                     8:3    0   39G  0 part
			├─VolGroup00-LogVol00  253:0    0    8G  0 lvm  /
			└─VolGroup00-LogVol01  253:1    0  1.5G  0 lvm  [SWAP]
		sdb                        8:16   0   10G  0 disk
		sdc                        8:32   0    2G  0 disk
		├─vg_var-lv_var_rmeta_0  253:2    0    4M  0 lvm
		│ └─vg_var-lv_var        253:6    0  952M  0 lvm  /var
		└─vg_var-lv_var_rimage_0 253:3    0  952M  0 lvm
		  └─vg_var-lv_var        253:6    0  952M  0 lvm  /var
		sdd                        8:48   0    1G  0 disk
		├─vg_var-lv_var_rmeta_1  253:4    0    4M  0 lvm
		│ └─vg_var-lv_var        253:6    0  952M  0 lvm  /var
		└─vg_var-lv_var_rimage_1 253:5    0  952M  0 lvm
		  └─vg_var-lv_var        253:6    0  952M  0 lvm  /var
		sde                        8:64   0    1G  0 disk
	
3.Выделить том под /home
	#Создаем LV под /home
	lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
	
	#Создаем ФС
	mkfs.xfs /dev/VolGroup00/LogVol_Home
	
	#Монтируем
	mount /dev/VolGroup00/LogVol_Home /mnt/
	
	#Копируем рекурсивно данные с /home
	cp -aR /home/* /mnt/
	
	#Удаляем текущий /home
	rm -rf /home/*
	
	#Монтируем новый /home 
	umount /mnt
	mount /dev/VolGroup00/LogVol_Home /home/
	
	#Правим fstab длā автоматического монтирования /home по аналогии с /var
	
	#Проверяем
	[root@lvm ~]# lsblk
	NAME                       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
	sda                          8:0    0   40G  0 disk
	├─sda1                       8:1    0    1M  0 part
	├─sda2                       8:2    0    1G  0 part /boot
	└─sda3                       8:3    0   39G  0 part
	  ├─VolGroup00-LogVol00    253:0    0    8G  0 lvm  /
	  ├─VolGroup00-LogVol01    253:1    0  1.5G  0 lvm  [SWAP]
	  └─VolGroup00-LogVol_Home 253:4    0    2G  0 lvm  /home
	sdb                          8:16   0   10G  0 disk
	sdc                          8:32   0    2G  0 disk
	├─vg_var-lv_var_rmeta_0    253:2    0    4M  0 lvm
	│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
	└─vg_var-lv_var_rimage_0   253:3    0  952M  0 lvm
	  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
	sdd                          8:48   0    1G  0 disk
	├─vg_var-lv_var_rmeta_1    253:5    0    4M  0 lvm
	│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
	└─vg_var-lv_var_rimage_1   253:6    0  952M  0 lvm
	  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
	sde                          8:64   0    1G  0 disk
	
4.Работа со снапшотами

	#Создадим пустые файлы в /home
	touch /home/file{1..10}
	[root@lvm home]# ll
		total 0
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file1
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file10
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file2
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file3
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file4
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file5
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file6
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file7
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file8
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file9
	
	#Снимаем снапшот
	lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
	
	#Смотрим
	[root@lvm home]# lsblk
		NAME                            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
		├─sda1                            8:1    0    1M  0 part
		├─sda2                            8:2    0    1G  0 part /boot	
		└─sda3                            8:3    0   39G  0 part
		  ├─VolGroup00-LogVol00         253:0    0    8G  0 lvm  /
		  ├─VolGroup00-LogVol01         253:1    0  1.5G  0 lvm  [SWAP]
		  ├─VolGroup00-LogVol_Home-real 253:8    0    2G  0 lvm
		  │ ├─VolGroup00-LogVol_Home    253:4    0    2G  0 lvm  /home
		  │ └─VolGroup00-home_snap      253:10   0    2G  0 lvm
		  └─VolGroup00-home_snap-cow    253:9    0  128M  0 lvm
			└─VolGroup00-home_snap      253:10   0    2G  0 lvm
		sdb                               8:16   0   10G  0 disk
		sdc                               8:32   0    2G  0 disk
		├─vg_var-lv_var_rmeta_0         253:2    0    4M  0 lvm
		│ └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
		└─vg_var-lv_var_rimage_0        253:3    0  952M  0 lvm
		  └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
		sdd                               8:48   0    1G  0 disk
		├─vg_var-lv_var_rmeta_1         253:5    0    4M  0 lvm
		│ └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
		└─vg_var-lv_var_rimage_1        253:6    0  952M  0 lvm
		  └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
		sde                               8:64   0    1G  0 disk
	
	#Для примера удалим несколько файлов
	rm -f /home/file{1..4}
	
	[root@lvm home]# ll
		total 0
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file10
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file5
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file6
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file7
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file8
		-rw-r--r--. 1 root    root     0 Jun 22 14:25 file9
		
	#И восстанавливаем со снапшота
	umount /home
	lvconvert --merge /dev/VolGroup00/home_snap 
	mount /home
	
	#Файлы восстановились
	
	#Вывод fstab
	#
	# /etc/fstab
	# Created by anaconda on Sat May 12 18:50:26 2018
	#
	# Accessible filesystems, by reference, are maintained under '/dev/disk'
	# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
	#
	/dev/mapper/VolGroup00-LogVol00 /                       xfs     defaults        0 0
	UUID=570897ca-e759-4c81-90cf-389da6eee4cc /boot                   xfs     defaults        0 0
	/dev/mapper/VolGroup00-LogVol01 swap                    swap    defaults        0 0
	#VAGRANT-BEGIN
	# The contents below are automatically generated by Vagrant. Do not modify.
	#VAGRANT-END
	UUID="43ab05e9-7f1f-4e64-b126-f51528712686" /var ext4 defaults 0 0
	UUID="83b6e5d1-e0ad-44f1-8e8c-615541ca8bdf" /home xfs defaults 0 0
	
	