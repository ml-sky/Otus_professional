#С помощью vagrantfile создается 2 ВМ "nfsserver" c ip 192.168.50.10 и "nfsclient" c ip 192.168.50.11
#На nfsserver с помощью скрипта nfsserver.sh настраивается "nfs шара" в каталоге /srv/share/upload_otus и выдается доступ на nfsclient
#На nfsclient с помощью скрипта nfsclient.sh "nfs шара" автоматически монтируется в каталог /mnt/upload_otus