#!/bin/bash
#
#-------------------------------------------------------------------
# Install script for MITSM standard Linux server setup
#
# v1.0 / Karl-Heinz Fichtlscherer
#
# if you want to have a log of all stuff, please call the script as following:
#
# mitsm_linux_setup.sh | tee -a /tmp/install.log
#
# The script will execute the following steps:
#
# -user rootmessages will be created and authorized for sudo
# -dotdeb repo will be added because we need PHP 7
# -git and curl will be installed
# -BPMspaceUG GIT repo will be cloned to /home/rootmessages
# -ssh configuration 
# -MySQL server installation
# -PHP7 will be installed (Apache Webserver will be installed as dependency
# -MITSM Apache configuration 
# -cron-apt for automatic security updates will be installed and configured
# -iptables configuration
# -apt-get update && apt-get upgrade
# -switch for prod or test environment (80/443 -> 4040/5050)
# -fixed bug. iptables script should be in place before sed stuff...
# -changed to MariaDB
# -added sudo package and sudo rules
#
#-------------------------------------------------------------------
# after the script has finished, we need a reboot for all changes
# ssh daemon will not be restarted during the setup because otherwise you will
# get kicked out 
#-------------------------------------------------------------------

ENV=$1

PORTS_CONF="/etc/apache2/ports.conf"
DEFAULT_CONF="/etc/apache2/sites-available/000-default.conf"
SSL_CONF="/etc/apache2/sites-available/default-ssl.conf"

usage () {

  echo "$0 <prod|test>"

}

if [ $# -ne 1 ];then

  usage
  exit 1

fi

case $ENV in

  prod)

        HTTP_PORT=80
        SSL_PORT=443
        ;;

  test)

        HTTP_PORT=4040
        SSL_PORT=5050
        ;;

  *)
        usage
        exit 1
        ;;

esac

echo " "
echo "creating user rootmessages..."
echo " "
adduser --quiet rootmessages 
adduser rootmessages sudo

echo "activate dotdeb repository"
echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list

echo ""
echo "import dotdeb gpg key...."
cd /tmp
wget https://www.dotdeb.org/dotdeb.gpg && apt-key add dotdeb.gpg && apt-get update

# add MariaDB repo
echo "MariaDB 10.1 repository list" >> /etc/apt/sources.list
echo "deb [arch=amd64,i386] http://ftp.hosteurope.de/mirror/mariadb.org/repo/10.1/debian jessie main" >> /etc/apt/sources.list

apt-get update > /dev/null 2>&1

echo "let's install git, curl and sudo"
apt-get install -y git curl sudo
echo " "
echo "done."

echo "let's clone the BPMspaceUG GIT repo...."
cd /home/rootmessages
git clone https://github.com/BPMspaceUG/linux_config_script_files.git

echo " "
echo "now we will do some configuration and installation stuff."
mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cp linux_config_script_files/daemon/sshd/sshd_config /etc/ssh/

mkdir /home/rootmessages/.ssh
chmod 700 /home/rootmessages/.ssh
cp linux_config_script_files/authorized_keys/authorized_keys /home/rootmessages/.ssh

# install MariaDB Server
apt-get install -y mariadb-server mariadb-client

mysql_secure_installation

# Install PHP 7 and Apache
apt-get install -y php7.0 php7.0-cli php7.0-curl php7.0-json php7.0-mysql php7.0-opcache

tar cvfz /etc/apache2.tar.gz /etc/apache2

cp -f linux_config_script_files/daemon/apache2/000-default.conf /etc/apache2/sites-available
cp -f linux_config_script_files/daemon/apache2/default-ssl /etc/apache2/sites-available/default-ssl.conf
cp -f linux_config_script_files/daemon/apache2/ports.conf /etc/apache2/

# Firewall stuff
echo "adding iptables script to /etc/rc.local"

mv /etc/rc.local /etc/rc.local.bak

echo "#!/bin/sh -e" > /etc/rc.local
echo "/opt/iptables.sh" >>/etc/rc.local
echo "exit 0" >> /etc/rc.local

# cp iptables.sh /opt
cp /home/rootmessages/linux_config_script_files/iptables/iptables.sh /opt
chmod u+x /opt/iptables.sh
chmod u+x /etc/rc.local

if [[ "$ENV" == "prod" ]];then

    sed -e "s/4040/$HTTP_PORT/g" $PORTS_CONF -i 
    sed -e "s/5050/$SSL_PORT/g" $PORTS_CONF -i 
    sed -e "s/4040/$HTTP_PORT/g" $DEFAULT_CONF -i
    sed -e "s/5050/$SSL_PORT/g" $SSL_CONF -i
    sed -e "s/4040/$HTTP_PORT/g" $DEFAULT_CONF -i
    sed -e "s/4040/$HTTP_PORT/g" /opt/iptables.sh -i
    sed -e "s/5050/$SSL_PORT/g" /opt/iptables.sh -i

  else
  
    echo "we are in $ENV, Ports stay on $HTTP_PORT and $SSL_PORT"
	
fi

a2enmod ssl
a2ensite 000-default default-ssl

echo "<h3>it works</h3>"> /var/www/index.html

service apache2 reload
chown -R rootmessages /home/rootmessages

# install cron-apt for automatic security updates
echo "installing cron-apt to provide automatic security updates...."
echo " "
apt-get install -y cron-apt

echo "creating /etc/apt/action.d/5-secupdates"
echo " "
echo "upgrade -y -o APT::Get::Show-Upgraded=true" >> /etc/cron-apt/action.d/5-secupdates

echo "creating /etc/apt/security.list"
echo " "
echo "deb http://security.debian.org/ jessie/updates main contrib" > /etc/apt/security.list
echo "deb-src http://security.debian.org/ jessie/updates main contrib" >> /etc/apt/security.list

echo "OPTIONS=\"-q -o Dir::Etc::SourceList=/etc/apt/security.list\"" >> /etc/cron-apt/config.d/5-secupdates

echo " "
echo "we want to have an up2date server, so let's update all stuff."
echo " "
apt-get update > /dev/null 2>&1
apt-get upgrade -y > /dev/null 2>&1

# sudo rules
echo "adding user to sudoers file...."
echo "rootmessages   ALL=(ALL)  NOPASSWD: ALL" >> /etc/sudoers

# add monitoring plugins and Icinga User

# let's check the ssh port and the apache / mysql stuff

echo "checking Apache webserver..."
echo "" 

curl -s http://localhost:${HTTP_PORT} > /dev/null

if [ $? -eq 0 ];then

    echo "Apache is accessible on port ${HTTP_PORT}"
 
  else 

   echo "Error. Apache Webserver not accessible on port ${HTTP_PORT}, please check"

fi

curl -s --insecure https://localhost:${SSL_PORT} > /dev/null

if [ $? -eq 0 ];then

    echo "Apache is accessible on port ${SSL_PORT} / ssl"
 
  else 

   echo "Error. Apache Webserver not accessible on port ${SSL_PORT}, please check"

fi

# check if MySQL is running

MYSQL_PID=`pgrep -fl "mysqld " | awk '{print $1}'`

if [ $? -eq 0 ];then

    echo "MySQL up and running, process ID: $MYSQL_PID"

  else

    echo "MySQL process not found, please check what's going on"

fi

echo "if you want to test if automatic security updates will work, please execute"
echo " "
echo "cron-apt -s"

echo " "
echo "setup done. Please reboot"
echo " "

