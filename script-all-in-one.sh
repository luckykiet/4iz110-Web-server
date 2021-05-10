#!/bin/bash

#########################################
#                                       #
# Script k seminarni prace z 4IZ110     #
#                                       #
# ubuntu web server                     #
#                                       #
# Autor: Tuan Kiet Nguyen               #
#                                       #
#########################################

#Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Parametry
owner=$(who am i | awk '{print $1}')
users=$(grep "/bin/bash" /etc/passwd | cut -d: -f1)
webDir='/var/www'
sitesEnabled='/etc/apache2/sites-enabled/'
sitesAvailable='/etc/apache2/sites-available/'

# Kontrola jestli jsme na root
if [ "$(whoami)" != 'root' ]; then
	echo -e "${RED}\nNemas pristupove pravo, pouzivej \'sudo\'!${NC}"
	exit 1
fi

# Volba akce
while [ "$action" != 1 ] && [ "$action" != 2 ] && [ "$action" != 3 ] && [ "$action" != 4 ]
do
	echo -e $"\nZvol si akci: ${GREEN}[1]Pridat uzivatele${NC}  ${RED}[2]Smazat uzivatele${NC} ${GREEN}[3]Spravovat domeny${NC}  ${YELLOW}[4]Instalace serveru${NC}"
	read action
done

#########################################
#                                       #
#            Pridat uzivatele           #
#                                       #
#########################################

if [[ "$action" == 1 ]]; then
	echo -e "${YELLOW}"
	read -p "Zadej uzivatelske jmeno : " username
	echo -e "${NC}"
	if id "$username" >/dev/null 2>&1; then
		echo -e "${RED}Uzivatel ${YELLOW}${username}${RED} jiz existuje!${NC}"
		exit 1
	else
		echo -e "${GREEN}V poradku!${NC}"
		while true; do
			echo -e "${YELLOW}"
			read -s -p "Zadej heslo: " password
			echo
			read -s -p "Zadej znovu heslo: " password2
			echo -e "${NC}"
			[ "$password" = "$password2" ] && break
			echo -e "${RED}Hesla nejsou shodna!${NC}"
		done
		echo -e "${GREEN}\nV poradku!${NC}"
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $password) #sifrovani hesla
		#[viz source.txt, 3]
		sudo useradd -m -p $pass $username
		if [ $? -eq 0 ];then
			
			echo -e "${GREEN}\nUzivatel ${YELLOW}${username}${GREEN} byl uspesne pridan!${NC}"
			while true; do
				echo -e "${YELLOW}"
				read -p "Zadej domenu : " domain
				echo -e "${NC}"
				echo
				if [[ $domain = *" "*  || $domain = "" || $domain = " " ]]; then
					echo -e "${RED}Neplatna domena! Zadej bez mezer!${NC}"
				else	
					sitesAvailabledomain=$sitesAvailable$domain.conf
					echo
					if [ -e $sitesAvailabledomain ]; then
						echo -e "${RED}\nDomena jiz existuje!${NC}"
					else
						break
					fi
				fi
			done
			
			#pridat pravo + soubor v apache2
			group="${username}-group"
			sudo mkdir -p $webDir/$group/$domain/
			echo -e "${YELLOW}\nBezi script ze stranky https://github.com/RoverWire/virtualhost ${NC}"
			sudo virtualhost create $domain $webDir/$group/$domain/
			sudo addgroup $group
			sudo adduser $username $group
			sudo chsh -s /bin/bash $username #bash pro uzivatel
			sudo usermod -d $webDir/$group/$domain/ $username #zmena defautni plochy uzivatele
			
			#zalozit mysql ucet + databaze
			echo "CREATE DATABASE IF NOT EXISTS \`${user}-${domain}\`;
			CREATE USER '${username}'@'%' IDENTIFIED BY '${password}';
			GRANT ALL PRIVILEGES ON \`${user}-${domain}\`.* TO '${username}'@'%';
			FLUSH PRIVILEGES;" > createuser.sql
			sudo chmod +x createuser.sql
			sudo mysql --defaults-extra-file=/srv/secrets/root@localhost.cnf --user=root --host=localhost --no-auto-rehash < createuser.sql
			sudo rm -rf createuser.sql
			
			#pridat pristupova prava
			sudo chown -vR :$group $webDir/$group/$domain/
			sudo chmod -vR g+w $webDir/$group/$domain/
			
			echo -e "${GREEN}\nOvereni domeny - ${YELLOW}${domain}${NC}"
			sleep 2
			ping -c4 $domain
			
			echo -e "${GREEN}\nUcet ${YELLOW}${username}${GREEN} uspesne vytvoren!${NC}"
		else
			echo -e "${RED}\nNepodarilo se, zkus to znovu!${NC}"
			exit 1
		fi	
	fi
fi	

#########################################
#                                       #
#            Smazat uzivatele           #
#                                       #
#########################################

if [[ "$action" == 2 ]]; then
	# Zobrazi aktualni uzivatele
	echo -e "${YELLOW}\nSeznam uzivatelu: ${NC}\n"
	echo $users

	# Prijme na vstup uzivatele ke smazani
	read -p "Zadej uzivatelske jmeno ke smazani : " username
	if id "$username" >/dev/null 2>&1; then
		group="${username}-group"
		dir=$(ls $webDir/$group | head -1 | wc -l)
		while [ $dir == 1 ]; do
			domain=$(ls $webDir/$group | head -1)
			sudo virtualhost delete $domain
			sudo rm -rf $webDir/$group/$domain
			dir=$(ls $webDir/$group | head -1 | wc -l)
		done
		
		#smazat mysql ucet + databaze
		echo "DROP DATABASE \`${user}-${domain}\`;
		DROP USER '${username}'@'%';
		FLUSH PRIVILEGES;" > deleteuser.sql
		sudo chmod +x deleteuser.sql
		sudo mysql --defaults-extra-file=/srv/secrets/root@localhost.cnf --user=root --host=localhost --no-auto-rehash < deleteuser.sql
		sudo rm -rf deleteuser.sql
		
		#smazat ucet + jeho soubory
		sudo rm -rf $webDir/$group /home/$username 2>/dev/null
		sudo groupdel -f $group 2>/dev/null
		sudo userdel -f $username  2>/dev/null
		
		echo -e "${GREEN}\nUzivatel $username kompletne smazan!${NC}"
	else
		echo -e "${RED}\nUzivatel $username neexistuje!${NC}"
		exit 1
	fi
fi
#########################################
#                                       #
#           Spravovani domen            #
#                                       #
#########################################

if [[ "$action" == 3 ]]; then
	users=$(grep "/bin/bash" /etc/passwd | cut -d: -f1)
	echo -e "${YELLOW}\nSeznam uzivatele: ${NC}\n"
	echo $users
	echo -e "${YELLOW}"
	read -p "Zadej uzivatelske jmeno: " username
	if ! id "$username" >/dev/null 2>&1; then
		echo -e "${RED}Uzivatel ${YELLOW}${username}${RED} neexistuje!${NC}"
		exit 1
	fi
	echo -e "${NC}"
	while [ "$choose" != 1 ] && [ "$choose" != 2 ]
	do
		echo -e $"\nZvol si akci: ${GREEN}[1]Pridat domenu${NC}  ${RED}[2]Smazat domenu${NC}"
		read choose 
	done

	group="${username}-group"
	showdomain="${webDir}/${group}/"

	# Pridat domenu
	if [[ "$choose" == 1 ]] ;then
		echo -e "${YELLOW}\nSeznam domen: ${NC}\n"
		echo $(ls -d ${webDir}/${group}/*/ |cut -d "/" -f 5 2>/dev/null)

		echo -e "${GREEN}"
		read -p "Zadej novou domenu: " domain
		echo -e "${NC}"
		sitesAvailabledomain=$sitesAvailable$domain.conf
		while [ -e $sitesAvailabledomain 2>/dev/null ] || [[ $domain = *" "*  || $domain = "" || $domain = " " ]]; do
			echo -e "${RED}Neplatna nebo domena existuje\n${NC}"
			read -p "Zadej novou domenu: " domain
			sitesAvailabledomain=$sitesAvailable$domain.conf
		done
		

		sudo mkdir -p $webDir/$group/$domain/
		echo -e "${YELLOW}\nBezi script ze stranky https://github.com/RoverWire/virtualhost ${NC}"
		sudo virtualhost create $domain $webDir/$group/$domain/

		echo "CREATE DATABASE IF NOT EXISTS \`${user}-${domain}\`;
		GRANT ALL PRIVILEGES ON \`${user}-${domain}\`.* TO '${username}'@'%';
		FLUSH PRIVILEGES;" > createuser.sql
		sudo chmod +x createuser.sql
		sudo mysql --defaults-extra-file=/srv/secrets/root@localhost.cnf --user=root --host=localhost --no-auto-rehash < createuser.sql
		sudo rm -rf createuser.sql

		sudo chown -vR :$group $webDir/$group/$domain/
		sudo chmod -vR g+w $webDir/$group/$domain/

		echo -e "${GREEN}\nOvereni domeny - ${YELLOW}${domain}${NC}"
		sleep 2
		ping -c4 $domain
				
		echo -e "${GREEN}\nDomena ${YELLOW}${domain}${GREEN} uspesne vytvoren!${NC}"
	fi

	if [[ "$choose" == 2 ]] ;then
		echo -e "${YELLOW}\nSeznam domen: ${NC}\n"
		echo $(ls -d ${webDir}/${group}/*/ |cut -d "/" -f 5 2>/dev/null)

		read -p "Zadej domenu ke smazani: " domain
		sitesAvailabledomain=$sitesAvailable$domain.conf
		while [ ! -f $sitesAvailabledomain 2>/dev/null ] || [[ $domain = *" "*  || $domain = "" || $domain = " " ]]; do
				echo -e "${RED}\nNeplatna nebo domena neexistuje${NC}"
				echo -e "${YELLOW}\nSeznam domen: ${NC}"
				echo $(ls -d ${webDir}/${group}/*/ |cut -d "/" -f 5 2>/dev/null)
				read -p "Zadej domenu ke smazani: " domain
				sitesAvailabledomain=$sitesAvailable$domain.conf
		done

		sudo virtualhost delete $domain

		#smazat mysql ucet + databaze
		echo "DROP DATABASE \`${user}-${domain}\`;
		FLUSH PRIVILEGES;" > deleteuser.sql
		sudo chmod +x deleteuser.sql
		sudo mysql --defaults-extra-file=/srv/secrets/root@localhost.cnf --user=root --host=localhost --no-auto-rehash < deleteuser.sql
		sudo rm -rf deleteuser.sql
			
		#smazat ucet + jeho soubory
		sudo rm -rf $webDir/$group/$domain 2>/dev/null
		echo -e "${GREEN}\nDomena $domain kompletne smazana!${NC}"
	fi
fi

#########################################
#                                       #
#           Instalace serveru           #
#                                       #
#########################################
if [[ "$action" == 4 ]]; then
	
	#parametry
	port=3306
	
	# Aktualizace
	echo -e "${YELLOW}\nProvede aktualizaci... ${NC}\n"
	sudo apt update -y
	sudo apt upgrade -y


	#Instalace apache2, mysql a potrebne knihovny
	echo -e "${YELLOW}\nProbiha instalace apache2, mysql a potrebne knihovny... ${NC}\n"
	sleep 3
	sudo apt install -y apache2 mysql-server gcc perl make
	sudo chown -R www-data:www-data $webDir
	sudo chmod -R g+rw $webDir

	#Konfigurace mysql
	if $(sudo mysql -e "quit" 2>/dev/null); then
		echo -e "${YELLOW}\nProbiha konfigurace MySQL...${NC}"
		sleep 3
		while true; do
			echo -e "${YELLOW}"
			read -s -p "Zadej nove heslo pro MySQL: " password
			echo
			read -s -p "Zadej znovu heslo pro MySQL: " password2
			echo -e "${NC}"
			[ "$password" = "$password2" ] && break
			echo -e "${RED}Hesla nejsou shodna!${NC}"
		done
		# [viz. source.txt, 4]
		# Make sure that NOBODY can access the server without a password
		sudo mysql -e "UPDATE mysql.user SET Password = PASSWORD('${password}') WHERE User = 'root'" 2>/dev/null
		# Kill the anonymous users
		sudo mysql -e "DROP USER ''@'localhost'" 2>/dev/null
		# Because our hostname varies we'll use some Bash magic here.
		sudo mysql -e "DROP USER ''@'$(hostname)'" 2>/dev/null
		# Kill off the demo database
		sudo mysql -e "DROP DATABASE test" 2>/dev/null
		# Make our changes take effect
		sudo mysql -e "FLUSH PRIVILEGES" 2>/dev/null
		# Any subsequent tries to run queries this way will get access denied because lack of usr/pwd param
		
		# Ulozit root heslo do souboru
		# [viz. source.txt, 5]
		sudo install -m 700 -d /srv/secrets/
		sudo install -m 600 /dev/null /srv/secrets/root@localhost.cnf
		echo -e "[client]\npassword=\"${password}\"" > root@localhost.cnf
		sudo mv root@localhost.cnf /srv/secrets/
		#Zmena typ hesla root z auth_socket na caching_sha2_password
		echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${password}';" > tmp.sql
		sudo mysql --defaults-extra-file=/srv/secrets/root@localhost.cnf --user=root --host=localhost --no-auto-rehash < tmp.sql
		sudo rm -rf tmp.sql
		
		#Zmena bind-address na 0.0.0.0 k verejnemu pristupu
		while [[ "$port" -lt 1000 ]] || [[ "$port" -gt 9999 ]]; do
			read -p "Zadej port v rozmezi (default 3306): " port
			if [[ "$port" == "" ]]; then
				port=3306
				break
			fi
		done
		sudo bash -c "echo 'port = $port' >> /etc/mysql/mysql.conf.d/mysqld.cnf"
		sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
		sudo service mysql restart
		echo -e "${GREEN}\nProbiha konfigurace mysql.....HOTOVO! ${NC}\n"
	fi

	# Instalace php8 a knihovny
	#[viz. source.txt, 6]

	echo -e "${YELLOW}\nProbiha instalace php... ${NC}\n"
	sleep 3

	sudo apt install software-properties-common -y
	sudo add-apt-repository ppa:ondrej/php -y
	sudo apt install -y php8.0 libapache2-mod-php8.0 php8.0-mysql php8.0-gd phpmyadmin php-mbstring php-zip php-gd php-json php-curl -y
	sudo a2enmod proxy_fcgi setenvif
	sudo a2enconf php8.0-fpm
	sudo phpenmod mbstring

	# Nejnovejsi phpmyadmin [viz. source.txt, 7]
	DATA="$(wget https://www.phpmyadmin.net/home_page/version.txt -q -O-)"
	URL="$(echo $DATA | cut -d ' ' -f 3)"
	VERSION="$(echo $DATA | cut -d ' ' -f 1)"
	wget https://files.phpmyadmin.net/phpMyAdmin/${VERSION}/phpMyAdmin-${VERSION}-all-languages.tar.gz
	sudo tar xvf phpMyAdmin-${VERSION}-all-languages.tar.gz
	sudo rm -rf  /usr/share/phpmyadmin
	sudo mkdir -p /usr/share/phpmyadmin
	sudo mv phpMyAdmin-*/* /usr/share/phpmyadmin
	sudo mkdir -p /var/lib/phpmyadmin/tmp
	sudo chown -R www-data:www-data /var/lib/phpmyadmin
	sudo mkdir /etc/phpmyadmin/ 2>/dev/null
	sudo cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php

	if ! $(grep "TempDir" -q /usr/share/phpmyadmin/config.inc.php); then
		TMP='\$cfg[\"TempDir\"] = \"/var/lib/phpmyadmin/tmp\"\;'
		sudo bash -c "echo -e $TMP" | sudo sed "s/\"/'/g" > tmp
		sudo bash -c "cat tmp >> /usr/share/phpmyadmin/config.inc.php"
		sudo rm -rf tmp
	fi
	sudo rm -rf phpMyAdmin-${VERSION}*
	randomBlowfishSecret=$(openssl rand -base64 32)
	sudo sed -i "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" /usr/share/phpmyadmin/config.inc.php

	#When the first prompt appears, apache2 is highlighted, but not selected. If you do not hit "SPACE" to select Apache, the installer will not move the necessary files during installation. Hit "SPACE", "TAB", and then "ENTER" to select Apache.
	echo -e "${GREEN}\nProbiha instalace php.....HOTOVO! ${NC}\n"

	#[viz. source.txt, 2]
	echo -e "${YELLOW}\nProbiha instalace scriptu virtualhost z https://github.com/RoverWire/virtualhost ... ${NC}\n"
	sleep 3
	cd /usr/local/bin
	sudo wget -O virtualhost https://raw.githubusercontent.com/RoverWire/virtualhost/master/virtualhost.sh
	sudo chmod +x virtualhost
	cd
	echo -e "${GREEN}\nProbiha instalace scriptu virtualhost.....HOTOVO! ${NC}\n"

	sudo systemctl restart apache2
	sudo apt update -y
	sudo apt upgrade -y
	echo -e "${GREEN}\nUspesne dokonceno!${NC}\n"
	echo -e "${YELLOW}\nPouzite zdroje:${NC}\n"
	echo -e 'https://www.digitalocean.com/community/tutorials/how-to-install-and-secure-phpmyadmin-on-ubuntu-20-04'
	echo -e 'https://github.com/RoverWire/virtualhost'
	echo -e 'http://www.cyberciti.biz/tips/howto-write-shell-script-to-add-user.html'
	echo -e 'https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script/35004940'
	echo -e 'https://stackoverflow.com/questions/34916074/how-to-pass-password-from-file-to-mysql-command/54492728'
	echo -e 'https://linuxize.com/post/how-to-install-php-8-on-ubuntu-20-04/'
	echo -e 'https://computingforgeeks.com/how-to-install-latest-phpmyadmin-on-ubuntu-debian/'
	
	exit
fi
