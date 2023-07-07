Предварительно устанавливаем инструменты для работы с SELinux
Все дальнейшие действия выполняются от root пользователя  sudo -i
yum install policycoreutils-python policycoreutils-newrole -y
yum install setools-console -y
yum install selinux-policy-mls -y
yum install setroubleshoot-server -y
1. Запустить nginx на нестандартном порту 3-мя разными способами (в Vagrantfile nginx имеет нестандартный порт 4881):
	1.1 Переключатели setsebool
	
		Анализируем лог /var/log/audit/audit.log и находим время блокировки nginx
		cat /var/log/audit/audit.log | grep nginx | grep denied
		Вывод:
		type=AVC msg=audit(1688534570.358:814): avc:  denied  { name_bind } for  pid=2819 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
		
		Копируем время, в которое был записан этот лог, и, с помощью утилиты audit2why смотрим
		grep 1688534570.358:814 /var/log/audit/audit.log | audit2why
		Вывод:
		type=AVC msg=audit(1688534570.358:814): avc:  denied  { name_bind } for  pid=2819 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly.
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1
		
		Утилита audit2why покажет почему трафик блокируется. Исходя из вывода утилиты, мы видим, что нам нужно поменять параметр nis_enabled.
		setsebool -P nis_enabled on
		Далее перезапускаем nginx и проверяем
		systemctl restart nginx
		systemctl status nginx
		
		Вывод:
		● nginx.service - The nginx HTTP and reverse proxy server
		Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
		Active: active (running) since Wed 2023-07-05 09:13:19 UTC; 6s ago
		Process: 22694 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
		Process: 22691 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
		Process: 22690 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
		Main PID: 22696 (nginx)
		CGroup: /system.slice/nginx.service
				├─22696 nginx: master process /usr/sbin/nginx
				└─22698 nginx: worker process

		Jul 05 09:13:19 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
		Jul 05 09:13:19 selinux nginx[22691]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
		Jul 05 09:13:19 selinux nginx[22691]: nginx: configuration file /etc/nginx/nginx.conf test is successful
		Jul 05 09:13:19 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
		
		[root@selinux ~]# ss -ntlp | grep nginx
		LISTEN     0      128          *:4881                     *:*                   users:(("nginx",pid=22698,fd=6),("nginx",pid=22696,fd=6))
		LISTEN     0      128       [::]:4881                  [::]:*                   users:(("nginx",pid=22698,fd=7),("nginx",pid=22696,fd=7))
		
		Можно также проверить параметр переключателя 
		[root@selinux ~]# getsebool -a | grep nis_enabled
		nis_enabled --> on
		
		Все nginx работает на нестандартном порту 4881
	
	1.2 Добавление нестандартного порта в имеющийся тип
	
		Ищем имеющийся тип с помощью semanage
		semanage port -l | grep http
		Вывод:
		http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
		http_cache_port_t              udp      3130
		http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
		pegasus_http_port_t            tcp      5988
		pegasus_https_port_t           tcp      5989
		
		Видим что порта 4881 нет, добавим его
		semanage port -a -t http_port_t -p tcp 4881
		
		Проверяем:
		http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
		http_cache_port_t              udp      3130
		http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
		pegasus_http_port_t            tcp      5988
		pegasus_https_port_t           tcp      5989
		
		Для проверки выключаем переключатель из предыдущего задания и проверяем
		setsebool -P nis_enabled off
		
		Вывод:
		[root@selinux ~]# getsebool -a | grep nis_enabled
		nis_enabled --> off
		[root@selinux ~]# systemctl restart nginx
		[root@selinux ~]# systemctl status nginx
		● nginx.service - The nginx HTTP and reverse proxy server
		Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
		Active: active (running) since Wed 2023-07-05 09:43:21 UTC; 1s ago
		Process: 22767 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
		Process: 22765 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
		Process: 22764 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
		Main PID: 22769 (nginx)
		CGroup: /system.slice/nginx.service
				├─22769 nginx: master process /usr/sbin/nginx
				└─22770 nginx: worker process

		Jul 05 09:43:21 selinux systemd[1]: Stopped The nginx HTTP and reverse proxy server.
		Jul 05 09:43:21 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
		Jul 05 09:43:21 selinux nginx[22765]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
		Jul 05 09:43:21 selinux nginx[22765]: nginx: configuration file /etc/nginx/nginx.conf test is successful
		Jul 05 09:43:21 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
		[root@selinux ~]# ss -ntlp | grep nginx
		LISTEN     0      128          *:4881                     *:*                   users:(("nginx",pid=22770,fd=6),("nginx",pid=22769,fd=6))
		LISTEN     0      128       [::]:4881                  [::]:*                   users:(("nginx",pid=22770,fd=7),("nginx",pid=22769,fd=7))
		
		Как видим nginx работает на нестандартном порту.
		
		Примечание: Удалить нестандартный порт из имеющегося типа можно с помощью команды semanage port -d -t http_port_t -p tcp 4881
		
	1.3 Работа nginx на нестандартном порту с помощью формирования и установки модуля SELinux
	
		Из предыдущего задания мы удалили порт 4881 из имеющегося типа:
		semanage port -d -t http_port_t -p tcp 4881
		
		Nginx после рестарта перестал работать, т.к SELinux снова начал блокировать его на нестандартном порту
		
		Для того чтобы сделать модуль проверим логи SELinux, отфильтровав nginx
		grep nginx /var/log/audit/audit.log
		
		Вывод:
		
		[root@selinux ~]# grep nginx /var/log/audit/audit.log
		type=SOFTWARE_UPDATE msg=audit(1688534569.905:812): pid=2693 uid=0 auid=1000 ses=2 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='sw="nginx-filesystem-1:1.20.1-10.el7.noarch" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="yum" exe="/usr/bin/python2.7" hostname=? addr=? terminal=? res=success'
		type=SOFTWARE_UPDATE msg=audit(1688534570.131:813): pid=2693 uid=0 auid=1000 ses=2 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='sw="nginx-1:1.20.1-10.el7.x86_64" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="yum" exe="/usr/bin/python2.7" hostname=? addr=? terminal=? res=success'
		type=AVC msg=audit(1688534570.358:814): avc:  denied  { name_bind } for  pid=2819 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
		type=SYSCALL msg=audit(1688534570.358:814): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=56346fce1878 a2=10 a3=7ffd82bc3110 items=0 ppid=1 pid=2819 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)
		type=SERVICE_START msg=audit(1688534570.363:815): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'
		type=SERVICE_START msg=audit(1688548399.472:917): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'
		type=SERVICE_STOP msg=audit(1688550169.730:925): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'
		type=SERVICE_START msg=audit(1688550169.771:926): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'
		type=SERVICE_STOP msg=audit(1688550201.790:927): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'
		type=SERVICE_START msg=audit(1688550201.811:928): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'
		type=SERVICE_STOP msg=audit(1688550498.096:929): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'
		type=AVC msg=audit(1688550517.319:933): avc:  denied  { name_bind } for  pid=22797 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
		type=SYSCALL msg=audit(1688550517.319:933): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=5559f2fe9878 a2=10 a3=7ffe38359c70 items=0 ppid=1 pid=22797 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)
		type=SERVICE_START msg=audit(1688550517.322:934): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'
	
		Далее воспользуемся утилитой audit2allow для того, чтобы на основе логов SELinux сделать модуль, разрешающий работу nginx на нестандартном порту
		grep nginx /var/log/audit/audit.log | audit2allow -M nginx
		
		Модуль сформирован и audit2allow вывел нам команду для применения модуля:
		******************** IMPORTANT ***********************
		To make this policy package active, execute:

		semodule -i nginx.pp
		
		Применяем модуль и проверяем
		semodule -i nginx.pp
		systemctl restart nginx
		systemctl status nginx
		
		Вывод:
		
		[root@selinux ~]# systemctl restart nginx
		[root@selinux ~]# systemctl status nginx
		● nginx.service - The nginx HTTP and reverse proxy server
		Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
		Active: active (running) since Wed 2023-07-05 11:33:15 UTC; 5s ago
		Process: 22868 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
		Process: 22866 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
		Process: 22865 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
		Main PID: 22870 (nginx)
		CGroup: /system.slice/nginx.service
				├─22870 nginx: master process /usr/sbin/nginx
				└─22872 nginx: worker process

		Jul 05 11:33:15 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
		Jul 05 11:33:15 selinux nginx[22866]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
		Jul 05 11:33:15 selinux nginx[22866]: nginx: configuration file /etc/nginx/nginx.conf test is successful
		Jul 05 11:33:15 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
		
		[root@selinux ~]# ss -ntlp | grep nginx
		LISTEN     0      128          *:4881                     *:*                   users:(("nginx",pid=22872,fd=6),("nginx",pid=22870,fd=6))
		LISTEN     0      128       [::]:4881                  [::]:*                   users:(("nginx",pid=22872,fd=7),("nginx",pid=22870,fd=7))
		
		Как видим nginx также работает на нестандартном порту 4881
		
		Дополнительно:
		Просмотр всех установленных модулей
		semodule -l
		Для удаления модуля воспользуемся командой (напримере nginx модуля)
		semodule -r nginx
		
		
2. Обеспечить работоспособность приложения при включенном selinux:

	2.1 Способ первый (из методички) Выполним клонирование репозитория
		git clone https://github.com/mbfx/otus-linux-adm.git
		Переходим в каталог со стендом
		cd otus-linux-adm/selinux_dns_problems
		
		Далее поднимаем vagrant стенды с двумя ВМ
		vagrant up 
		
		root@VM-Ubuntu-prof:~/otus-linux-adm/selinux_dns_problems# vagrant status
		Current machine states:

		ns01                      running (virtualbox)
		client                    running (virtualbox)

		Подключаемся к client
		vagrant ssh client
		Попробуем внести изменения в зону
		nsupdate -k /etc/named.zonetransfer.key
		
		Вывод:
		[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
		> server 192.168.50.10
		> zone ddns.lab
		> update add www.ddns.lab. 60 A 192.168.50.15
		> send
		update failed: SERVFAIL
		
		Получаем ошибку, и далее пробуем разобраться с проблемой
	
		Переходим под root
		sudo -i
		
		И воспользуемся утилитой audit2why и проверим логи SELinux
		[root@client ~]# cat /var/log/audit/audit.log | audit2why
		[root@client ~]#
		Ошибок на самом клиенте не найдено
		
		Проверяем также вторую ВМ ns01
		[vagrant@ns01 ~]$ sudo -i
		[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why
		type=AVC msg=audit(1688626567.629:1914): avc:  denied  { create } for  pid=5105 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file permissive=0
		Was caused by:
		Missing type enforcement (TE) allow rule.
		You can use audit2allow to generate a loadable module to allow this access.
		
		Как мы видим ошибка в логах связана с контектом безопасности. Вместо типа named_t используется тип etc_t
		
		[root@ns01 ~]# ls -laZ /etc/named
		drw-rwx---. root named system_u:object_r:etc_t:s0       .
		drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
		drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
		-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
		-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
		-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
		-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab
		Как мы также видим, что контекст безопасности неправильный. Проблема заключается в том, что конфигурационные файлы лежат в другом каталоге.
		[root@ns01 ~]# semanage fcontext -l | grep named
		/etc/rndc.*                                        regular file       system_u:object_r:named_conf_t:s0 
		/var/named(/.*)?                                   all files          system_u:object_r:named_zone_t:s0 
		
		Изменим тип контекста безопасности для каталога /etc/named
		chcon -R -t named_zone_t /etc/named
		
		Проверим
		
		ls -laZ /etc/named
		
		Вывод:
		drw-rwx---. root named system_u:object_r:named_zone_t:s0 .
		drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
		drw-rwx---. root named unconfined_u:object_r:named_zone_t:s0 dynamic
		-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.50.168.192.rev
		-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab
		-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab.view1
		-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.newdns.lab
		
		Также возвращаемя на клиент ВМ и проверяем
		
		[root@client ~]# nsupdate -k /etc/named.zonetransfer.key
		> server 192.168.50.10
		> zone ddns.lab
		> update add www.ddns.lab. 60 A 192.168.50.15
		> send
		> quit
		
		[root@client ~]# dig www.ddns.lab
		; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.13 <<>> www.ddns.lab
		;; global options: +cmd
		;; Got answer:
		;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4800
		;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

		;; OPT PSEUDOSECTION:
		; EDNS: version: 0, flags:; udp: 4096
		;; QUESTION SECTION:
		;www.ddns.lab.			IN	A

		;; ANSWER SECTION:
		www.ddns.lab.		60	IN	A	192.168.50.15

		;; AUTHORITY SECTION:
		ddns.lab.		3600	IN	NS	ns01.dns.lab.

		;; ADDITIONAL SECTION:
		ns01.dns.lab.		3600	IN	A	192.168.50.10

		;; Query time: 3 msec
		;; SERVER: 192.168.50.10#53(192.168.50.10)
		;; WHEN: Thu Jul 06 12:09:45 UTC 2023
		;; MSG SIZE  rcvd: 96

		Все изменения применились. Для того, чтобы вернуть правила обратно, можно ввести команду
		restorecon -v -R /etc/named

	2.2 Способ второй.Проверяем все ошибки SELinux последовательно и создаем модули по их исправлению

			audit2why < /var/log/audit/audit.log
			
			Вывод:
			[root@ns01 ~]# audit2why < /var/log/audit/audit.log
			type=AVC msg=audit(1688711673.690:1879): avc:  denied  { write } for  pid=5107 comm="isc-worker0000" name="named" dev="sda1" ino=67549619 scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:named_zone_t:s0 tclass=dir permissive=0

			Was caused by:
			The boolean named_write_master_zones was set incorrectly. 
			Description:
			Allow named to write master zones

			Allow access by executing:

			# setsebool -P named_write_master_zones 1
			
			Далее используем утилиту audit2allow
			audit2allow -M named-selinux --debug < /var/log/audit/audit.log
			
			Вывод:
			[root@ns01 ~]# audit2allow -M named-selinux --debug < /var/log/audit/audit.log

			******************** IMPORTANT ***********************

			To make this policy package active, execute:

			semodule -i named-selinux.pp
			
			Делаем политику активной выполнив:
			semodule -i named-selinux.pp
			
			Проверяем командами cat /var/log/messages | grep ausearch
			
			Вывод:
			[root@ns01 ~]# cat /var/log/messages | grep ausearch
			Jul  7 06:34:35 localhost python: SELinux is preventing /usr/sbin/named from write access on the directory named.#012#012*****  Plugin catchall_boolean (89.3 confidence) suggests   ******************#012#012If you want to allow named to write master zones#012
			Then you must tell SELinux about this by enabling the 'named_write_master_zones' boolean.#012#012Do#012setsebool -P named_write_master_zones 1#012#012*****  Plugin catchall (11.6 confidence) suggests   
			**************************#012#012If you believe that named should be allowed write access on the named directory by default.#012Then you should report this as a bug.#012You can generate a local policy module to allow this access.
			#012Do#012allow this access for now by executing:#012# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000#012# semodule -i my-iscworker0000.pp#012
			
			Разобрав вывод мы видим что SELinux  все еще запрещает /usr/sbin/named доступ для записи в указанный каталог и для решения предалагается вариант выполнить несколько команд:
			
			semanage fcontext -a -t dnssec_trigger_var_run_t 'named.ddns.lab.view1.jnl'
			restorecon -v '/etc/named/dynamic/named.ddns.lab.view1.jnl'
			ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000 | semodule -i my-iscworker0000.pp
			
			Проверяем, видим что появилась другая ошибка
			
			Вывод:
			Jul  7 08:02:22 localhost python: SELinux is preventing /usr/sbin/named from create access on the file tmp-AYJmROtAwz.#012#012*****  Plugin catchall_boolean (89.3 confidence) suggests   ******************#012#
			012If you want to allow named to write master zones#012Then you must tell SELinux about this by enabling the 'named_write_master_zones' boolean.#012#
			012Do#012setsebool -P named_write_master_zones 1#012#012*****  Plugin catchall (11.6 confidence) suggests   **************************#012#
			012If you believe that named should be allowed create access on the tmp-AYJmROtAwz file by default.
			#012Then you should report this as a bug.#
			012You can generate a local policy module to allow this access.#012Do#012allow this access for now by executing:#012# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000#012# semodule -i my-iscworker0000.pp#012
			
			Включаем переключатель SELinux
			setsebool -P named_write_master_zones 1
			
			Удаляем файл /etc/named/dynamic/named.ddns.lab.view1.jnl
			rm /etc/named/dynamic/named.ddns.lab.view1.jnl
			Перезапускаем сервис DNS сервера 
			systemctl restart named 
			[root@ns01 ~]# systemctl status named
			● named.service - Berkeley Internet Name Domain (DNS)
			Loaded: loaded (/usr/lib/systemd/system/named.service; enabled; vendor preset: disabled)
			Active: active (running) since Fri 2023-07-07 08:14:10 UTC; 9s ago
				Process: 25816 ExecStop=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID (code=exited, status=0/SUCCESS)
				Process: 25829 ExecStart=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS (code=exited, status=0/SUCCESS)
				Process: 25827 ExecStartPre=/bin/bash -c if [ ! "$DISABLE_ZONE_CHECKING" == "yes" ]; then /usr/sbin/named-checkconf -z "$NAMEDCONF"; else echo "Checking of zone files is disabled"; fi (code=exited, status=0/SUCCESS)
			Main PID: 25831 (named)
				CGroup: /system.slice/named.service
					└─25831 /usr/sbin/named -u named -c /etc/named.conf


				Jul 07 08:14:10 ns01 named[25831]: automatic empty zone: view default: HOME.ARPA
				Jul 07 08:14:10 ns01 named[25831]: none:104: 'max-cache-size 90%' - setting to 211MB (out of 235MB)
				Jul 07 08:14:10 ns01 named[25831]: command channel listening on 192.168.50.10#953
				Jul 07 08:14:10 ns01 named[25831]: managed-keys-zone/view1: journal file is out of date: removing journal file
				Jul 07 08:14:10 ns01 named[25831]: managed-keys-zone/view1: loaded serial 6
				Jul 07 08:14:10 ns01 named[25831]: managed-keys-zone/default: journal file is out of date: removing journal file
				Jul 07 08:14:10 ns01 named[25831]: managed-keys-zone/default: loaded serial 6
				Jul 07 08:14:10 ns01 named[25831]: zone 0.in-addr.arpa/IN/view1: loaded serial 0
				Jul 07 08:14:10 ns01 named[25831]: zone ddns.lab/IN/view1: loaded serial 2711201407
				Jul 07 08:14:10 ns01 systemd[1]: Started Berkeley Internet Name Domain (DNS).


			И больше не видим ошибок, теперь динамическое обновление выполняется успешно.
			
			Проверка на client:
			[root@client ~]# nsupdate -k /etc/named.zonetransfer.key
			> server 192.168.50.10
			> zone ddns.lab
			> update add www.ddns.lab. 60 A 192.168.50.15
			> send
			> quit
			
			[root@client ~]# dig www.ddns.lab

			; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.13 <<>> www.ddns.lab
			;; global options: +cmd
			;; Got answer:
			;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 64520
			;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

			;; OPT PSEUDOSECTION:
			; EDNS: version: 0, flags:; udp: 4096
			;; QUESTION SECTION:
			;www.ddns.lab.			IN	A

			;; ANSWER SECTION:
			www.ddns.lab.		60	IN	A	192.168.50.15

			;; AUTHORITY SECTION:
			ddns.lab.		3600	IN	NS	ns01.dns.lab.

			;; ADDITIONAL SECTION:
			ns01.dns.lab.		3600	IN	A	192.168.50.10

			;; Query time: 1 msec

			;; SERVER: 192.168.50.10#53(192.168.50.10)

			;; WHEN: Fri Jul 07 08:18:08 UTC 2023

			;; MSG SIZE  rcvd: 96
			
			После перезагрузки настройки сохранились.
			
	2.3 Еще есть самый примитивный способ - выключить SELinux. Данный вариант не рекомендуется.







			


			







		

