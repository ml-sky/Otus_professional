#!/bin/bash

echo -e 'Скрипт является примитивным аналогом утилиты ps. Выводит в читаемом формате следующее:\n
PID процесса\n
USER-Имя пользователя от кого запущен процесс\n
COMMAND-комманда, запустившая данный процесс\n
STAT-состояние процесса\n
RSS-размер страниц памяти, если есть указзаная информация\n'


#Формат вывода через printf присваиваем переменной
format="%-30s%-30s%-85s%-10s%-10s\n"

#Выводим название столбцов через printf
printf "$format" PID USER COMMAND STAT RSS

#Цикл для proc с перебором всех PID
for proc in `ls /proc/ | egrep "^[0-9]" | sort -n`
do
    if [[ -f /proc/$proc/status ]]
        then
        PID=$proc
	
	#Присваеваем переменной COMMAND команду
    COMMAND=`cat /proc/$proc/cmdline`
	
	#Если содержимого нет (пустая строка) то выводим через awk COMMAND /proc/$proc/status , если содержимое есть то COMMAND выводим cat /proc/$proc/cmdline
    if  [[ -z "$COMMAND" ]]
        then
        COMMAND="[`awk '/Name/{print $2}' /proc/$proc/status`]"
    else
        COMMAND=`cat /proc/$proc/cmdline`
    fi
	#Содержимое столбца User (только Uid), Stat,RSS выводим через awk в /proc/$proc/status
    User=`awk '/Uid/{print $2}' /proc/$proc/status`
    Stat=`cat /proc/$proc/status | awk '/State/{print $2}'`
    RSS=`cat /proc/$proc/status | awk '/VmRSS/{print $2}'`
	
	#Сравнение UID с 0 и вывод в Username , если = 0 то root , если нет то выводим через awk из /etc/passwd
    if [[ User -eq 0 ]]
       then
       UserName='root'
    else
       UserName=`grep $User /etc/passwd | awk -F ":" '{print $1}'`
    fi
	#Вывод содержимого на экран через printf
    printf "$format" $PID $UserName "$COMMAND" $Stat $RSS
    fi
done
