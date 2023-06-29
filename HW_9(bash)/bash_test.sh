#!/bin/bash

#Считывание количества строк и запись в переменную
num=$(cat ./lines 2>/dev/null);status=$?

#Подсчет количества строк в файле access-test.log и вывод через awk
Lines=$(wc ./access-test.log | awk '{print $1}')

#Условие для проверки файла lines на пустоту, если возвращается пустое значение то считаем количество строк и записываем в файл lines
if ! [ -n "$num" ]
	then
#Дата начала (выводим 4 и 5 столбец, первая строка с исключением квадратных скобок)
DataHead=$(awk '{print $4 $5}' access-test.log | sed 's/\[//; s/\]//' | sed -n 1p)

#Дата конца (выводим 4 и 5 столбец, последняя строка с исключением квадратных скобок, последняя строка считается через переменную Lines)
DataLast=$(awk '{print $4 $5}' access-test.log | sed 's/\[//; s/\]//' | sed -n "$Lines"p)

# Запись количества строк в файле access-test и вывод в файл lines
echo $Lines > ./lines
	
#Вывод через awk количества запросов с сортировкой по ip
ip=$(awk '{print $1}' access-test.log | sort | uniq -c | sort -rn | awk '{ if ( $1 >= 0 ) { print "Количество запросов:" $1, "IP:" $2 } }')

#Количество запрашиваемых URL с сортировкой по URL
url=$(awk '($9 ~ /200/)' access-test.log | awk '{print $7}' | sort | uniq -c | sort -rn | awk '{ if ( $1 >= 10 ) { print "Количество запросов:" $1, "URL:" $2 } }')

#Список всех кодов, включая ошибки (выводим нужный столбец через утилиту cut , сначала 3 стобец - разделитель " , после 2 столбец из оставшихся - разделитель пробел, далее сортировка).
code=$(cat access-test.log | cut -d '"' -f3 | cut -d ' ' -f2 | sort | uniq -c | sort -rn | awk '{print "Количество:" $1, "Код запроса:" $2}')

#Отправка данных на почту
echo -e "Данные за период:$DataHead-$DataLast\n$ip\n\n"Запрашиваемые URL:"\n$url\n\n"HTTP Code:"\n$code" | mail -s "Логи nginx" root@localhost 

	else

#Дата начала (выводим 4 и 5 столбец, первая строка с исключением квадратных скобок, начало проверяется с помощью количества строк в  файле lines)
DataHead=$(awk '{print $4 $5}' access-test.log | sed 's/\[//; s/\]//' | sed -n "$(($num+1))"p)

#Дата конца (выводим 4 и 5 столбец, последняя строка с исключением квадратных скобок, последняя строка считается через переменную Lines)
DataLast=$(awk '{print $4 $5}' access-test.log | sed 's/\[//; s/\]//' | sed -n "$Lines"p)
	
#Вывод через awk количества запросов с сортировкой по ip
ip=$(awk '{print $1}' access-test.log | sort | uniq -c | sort -rn | awk '{ if ( $1 >= 0 ) { print "Количество запросов:" $1, "IP:" $2 } }')

#Количество запрашиваемых URL с сортировкой по URL
url=$(awk '($9 ~ /200/)' access-test.log | awk '{print $7}' | sort | uniq -c | sort -rn | awk '{ if ( $1 >= 10 ) { print "Количество запросов:" $1, "URL:" $2 } }')

#Список всех кодов, включая ошибки (выводим нужный столбец через утилиту cut , сначала 3 стобец - разделитель " , после 2 столбец из оставшихся - разделитель пробел, далее сортировка).
code=$(cat access-test.log | cut -d '"' -f3 | cut -d ' ' -f2 | sort | uniq -c | sort -rn | awk '{print "Количество:" $1, "Код запроса:" $2}')

# Запись количества строк в файле access-test и вывод в файл lines
echo $Lines > ./lines

#Отправка данных на почту
echo -e "Данные за период:$DataHead-$DataLast\n$ip\n\n"Запрашиваемые URL:"\n$url\n\n"HTTP Code:"\n$code" | mail -s "Логи nginx" root@localhost 

fi