#/bin/bash

# Запускаем одновременно 2 команды с разным приоритетом, для сравнения удобно использовать старую команду dd и копировать в dev/null
time nice -n -10 su -c "dd if=/dev/zero of=/dev/null bs=1000 count=1M" &  time nice -n 20 su -c "dd if=/dev/zero of=/dev/null bs=1000 count=1M"

#Результат из консоли:

#1048576+0 records in
#1048576+0 records out
#1048576000 bytes (1.0 GB) copied, 1.2214 s, 859 MB/s

#real    0m1.235s
#user    0m0.596s
#sys     0m0.628s

#1048576+0 records in
#1048576+0 records out
#1048576000 bytes (1.0 GB) copied, 4.10132 s, 256 MB/s              

#real    0m5.383s
#user    0m1.132s
#sys     0m1.296s