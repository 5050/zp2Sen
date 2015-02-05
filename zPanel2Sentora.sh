#! /bin/bash
echo <<<EOF
--- THIS UPDATER IS NOT COMPLETED.
--- IT MUST NOT BE USED before officially released.
--- Removing this section and running it WILL BROKE YOUR SERVER.
EOF
exit 1;

PANEL_PATH="/etc/sentora"
PANEL_DATA="/var/sentora"
PANEL_CONF="$PANEL_PATH/configs"

#--- Ensure all requirements are Ok

# Check if OS is compatible
BITS=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
if [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif [ -f /etc/centos-release ]; then
    OS="CentOs"
    VERFULL=$(sed 's/^.*release //;s/ (Fin.*$//' /etc/centos-release)
    VER=${VERFULL:0:1} # return 6 or 7
else
    OS=$(uname -s)
    VER=$(uname -r)
fi
echo "Detected : $OS  $VER  $BITS"

if [[ "$OS" = "CentOs" && ("$VER" = "6" || "$VER" = "7" ) || 
      "$OS" = "Ubuntu" && ("$VER" = "12.04" || "$VER" = "14.04" ) ]] ; then 
    echo "Ok."
else
    echo "Sorry, this OS is not supported by Sentora." 
    exit 1;
fi

# Check if the user is 'root' before allowing installation to commence
if [ $UID -ne 0 ]; then
    echo "Install failed: you must be logged in as 'root' to install."
    echo "Use command 'sudo -i', then enter root password and then try again."
    exit 1
fi

# Ensure zpanel is installed
if [[ ! -d "/etc/zpanel" || ! -d "/var/zpanel" ]]; then
    echo "ZPanel seems to be not installed on this server. Bye!"
    exit 1
fi

#--- Stop all services
if [[ "$OS" = "CentOs" ]]; then
    HTTP_SERVICE="httpd"
    BIND_SERVICE="named"
    CRON_SERVICE="crond"
elif [[ "$OS" = "Ubuntu" ]]; then
    HTTP_SERVICE="apache2"
    BIND_SERVICE="bind9"
    CRON_SERVICE="cron"
fi
service mysql stop
service "$HTTP_SERVICE" stop
service postfix stop
service dovecot stop
service "$CRON_SERVICE" stop
service "$BIND_SERVICE" stop
service proftpd stop
service atd stop

#--- Rename master directories and create ln for compatibility
mv "$PANEL_PATH" /etc/sentora
ln -s "PANEL_PATH" /etc/zpanel
mv "PANEL_DATA" /var/sentora
ln -s "PANEL_DATA" /var/zpanel

#Rename misc directories or files
mv /etc/sentora/panel/etc/dryden/ui/tpl/zpanelversion.class.php /etc/sentora/panel/etc/dryden/ui/tpl/sentoraversion.class.php
mv /etc/sentora/panel/etc/lib/pChart2/zpanel /etc/sentora/panel/etc/lib/pChart2/sentora
mv /etc/sentora/panel/etc/lib/pChart2/palettes/zpanel.color /etc/sentora/panel/etc/lib/pChart2/palettes/sentora.color
mv /etc/sentora/panel/etc/styles/zpanelx /etc/sentora/panel/etc/styles/Sentora_Default
mv /etc/sentora/panel/etc/styles/Sentora_Default/js/zpanel.js /etc/sentora/panel/etc/styles/Sentora_Default/js/sentora.js
mv /etc/sentora/panel/etc/styles/Sentora_Default/img/modules/zpanelconfig /etc/sentora/panel/etc/styles/Sentora_Default/img/modules/sentoraconfig
mv /etc/sentora/panel/modules/zpanelconfig /etc/sentora/panel/modules/sentoraconfig

#--- Update files
update_file() {
    sed -i "s|Zpanel|Sentora|;s|ZPanel|Sentora|;s|zpanel|sentora|I;" $1
    sed -i "s|Sentora|zPanel|I;" $1
}

# Config files
find /etc/zpanel/config/ -type f -exec update_file {} \;

#--- System files out of sentora dirs
# Apache master file
update_file /etc/apache2/apache2.conf


#--- Rename master databases
MYSQL_PASS=$(cat /etc/zpanel/panel/cnf/db.php | grep "pass =" | sed -s "s|.*pass \= '\(.*\)';.*|\1|")
rename_db(){
  mysqldump --quick --single-transaction --routines --triggers -u root -p"$MYSQL_PASS" "zpanel_$1" > /tmp/zptemp.sql
  mysql -u root -p"$MYSQL_PASS" <<EOF
  CREATE DATABASE sentora_$1;
  USE sentora_$1;
  SOURCE /tmp/zptemp.sql;
  UPDATE mysql.db SET Db='sentora_$1' WHERE Db='zpanel_$1';
  UPDATE mysql.host SET Db='sentora_$1' WHERE Db='zpanel_$1';
  UPDATE mysql.tables_priv SET Db='sentora_$1' WHERE Db='zpanel_$1';
  UPDATE mysql.columns_priv SET Db='sentora_$1' WHERE Db='zpanel_$1';
  UPDATE mysql.procs_priv SET Db='sentora_$1' WHERE Db='zpanel_$1';
  FLUSH PRIVILEGES;
  DROP DATABASE zpanel_$1;
EOF
  rm /tmp/zptemp.sql
}

rename_db "core"
rename_db "postfix"
rename_db "proftpd"
rename_db "roundcube"

#--- Databases content
# name of default style
mysql -u root -p"$mysqlpassword" -e 'USE sentora_core; UPDATE x_accounts SET ac_usertheme_vc="Sentora_Default" WHERE ac_usertheme_vc="zpanelx"';

# replace in databases
update_table(){
    mysql -u root -p"$MYSQL_PASS" << EOF
    UPDATE $1 SET $2 = REPLACE($2, 'ZPanel', 'Sentora');
    UPDATE $1 SET $2 = REPLACE($2, 'Zpanel', 'Sentora');
    UPDATE $1 SET $2 = REPLACE($2, 'zpanel', 'sentora');
EOF    
}
update_table sentora_core.x_accounts ac_notice_tx
update_table sentora_core.x_conjobs ct_fullpath_vc


#--- turn databese and their content to UTF8


#--- remove Listen from main apache conf file


#--- replace modules.zpanelcp.com/repo inside /etc/zppy-cache

#update modules.xml links
find /etc/sentora/panel/modules -name module.xml -exec sed -i 's|www.zpanelcp.com/uds/core.xml|store.sentora.org/version.xml|' {} \;



#--- Start all services
service mysql start
service "$HTTP_SERVICE" start
service postfix start
service dovecot start
service "$CRON_SERVICE" start
service "$BIND_SERVICE" start
service proftpd start
service atd start
