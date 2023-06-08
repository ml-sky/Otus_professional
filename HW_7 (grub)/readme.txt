1)#Восстановление пароля (добавление  init=/bin/sh)

#Далее перемонтируем ФС в режим rw
mount -o remount,rw /
#меняем пароль
passwd root

#Восстановление пароля (добавление rd.break, для RHel систем)

#перемонтируем на запись sysroot
mount -o remount,rw /sysroot

#меняем кореневую директорию root на sysroot
chroot /sysroot

#Меняем пароль root
passwd root

#Для применения изменений (SELinux)
touch /.autorelabel

2)	#Смена VolumeGroup в LVM

#Переименование VG
vgrename OtusRoot OtusProf

#Далее необходимо поменять название VG в файлах /etc/fstab, /etc/default/grub, /boot/grub2/grub.cfg
#Пересоздаем далее initrd
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)

#Перезагружаем компьютер, и видим что название VG поменялось

3)	Добавление модуля в initrd
# Скрипты модулей хранятся в каталоге /usr/lib/dracut/modules.d/. Для того чтобы добавить свой модуль создаем там папку с именем 01test,
mkdir /usr/lib/dracut/modules.d/01test

#Далее создаем там 2 скрипта - module-setup.sh и test.sh, делаем их исполняемыми chmod +x.

#В скрипт module-setup.sh вписываем:
#!/bin/bash

check() { # Функция, которая указывает что модуль должен быть включен по умолчанию
    return 0
}

depends() { # Выводит все зависимости от которых зависит наш модуль
    return 0
}

install() {
    inst_hook cleanup 00 "${moddir}/test.sh" # Запускает скрипт
}
#В скрипт test.sh вписываем:

#!/bin/bash

cat <<'msgend'
Hello! You are in dracut module!
 ___________________
< I'm dracut module >
 -------------------
   \
    \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
msgend
sleep 10
echo " continuing...."
#Далее выполняем команду 
dracut -f -v
#Перезагружаемся , убираем вручную опции rghb и quiet и получаем при запуске пингвина





