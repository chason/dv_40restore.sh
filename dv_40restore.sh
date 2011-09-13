#!/bin/bash

##Define important variables:

[[ $1 == "" ]] && RESTORE_DIR=/old || RESTORE_DIR=$1 ;

BACKUP_DIR=/opt/mt_restore_backup ;

IMPORTANT_FILES=( /etc/passwd  \
/etc/group \
/etc/shadow  \
/etc/httpd/conf.d/zz010_psa_httpd.conf \
/usr/local/psa/admin/htdocs/domains/databases/phpMyAdmin/libraries/config.default.php  \
#/etc/psa/.webmail.shadow  \
#/etc/psa-webmail/horde/.horde.shadow
#/etc/psa-webmail/atmail/.atmail.shadow
/etc/psa/.psa.shadow );

IMPORTANT_DIRECTORIES=( /var/www/vhosts \
/var/qmail \
/var/named/run-root/etc \
/var/spool/cron  \
/var/lib/mysql \
/var/lib/psa/dumps  \
#/etc/psa-horde \
#/etc/psa-webmail 
);

BACKUP_DIRS=(   /etc \
/vhosts \
/qmail \
/run-root \
/conf.d  \
/PSAphpMyAdmin \
/webmail \
/crons  \
/certificates \
/mysql \
/dumps );


echo'';
echo 'PLEASE READ CAREFULLY....';
echo '';
echo '';
echo "This script is for automatically restoring Plesk configuration and domain data on (dv)s that were forced to re-install becaused they were root hacked. This script will not work for customized (dv)s or (dv)s provisioned without Plesk.  The intention of this script is to assist (dv)s that were rooted but appeared to still be running normally after a re-install. If you needed to re-install because you did something like 'rm -rf /*' this script will not help you. When restoring from rooted (dv)s, please carefully audit all web viewable files in '/old/var/www/vhosts/(domain)/(httpdocs|httpsdocs|cgi-bin)'  and ESPECIALLY '/var/spoon/cron/*' files before using this script.  It is very common to see malicious scripts added to a domain files or a cronjob added to re-hack your server. ";
echo '';


read -p 'Do you wish continue with the restore? YES/no : ' USESCRIPT
if [ "$USESCRIPT" != "YES"  ]; then
echo  'Bye!!';
exit 0;
fi


##Checking for the existance of all the files and direcotries we will be using to avoid any unexpected results.

echo "";
echo "Running Restore pre-check.....";
sleep 2;
echo "";
echo "checking for $RESTORE_DIR";
sleep 2;

if [ ! -d $RESTORE_DIR ]; then
echo "No $RESTORE_DIR directory!";
echo 'Sorry. There is nothing to restore.'
exit 0;
else
echo "$RESTORE_DIR found.";
fi

echo"";
echo"";

echo "Checking disk space..."
sleep 2;
DISKSPACE=$( df | grep \ /$ | awk '/^\/dev/{print $5}' | sed -e "s/\%//" );

if [ ${DISKSPACE} -gt 50 ]; then
echo "${DISKSPACE}% used. There is not enough disk space left to restore your data.  You will need to temporarily upgrade to get more space before you can continue with the restore script.";
echo "Aborting Restore";
exit 0;
else
echo "Only ${DISKSPACE}% disk space used, continuing...";
fi

echo;
echo;

echo "Checking for important files in /old and current root...";
sleep 2;
for FILE in ${IMPORTANT_FILES[@]}
do
if [ ! -f ${RESTORE_DIR}${FILE} ]; then

echo "${RESTORE_DIR}$FILE not found.";
echo 'Unable to continue automatically.  Server back-up incomplete or original server was customized.'
exit 0;
#	else
#		echo "${RESTORE_DIR}$FILE found.";
fi

if [ ! -f ${FILE} ]; then

echo "$FILE not found.";
echo 'Unable to continue automatically.  Current server was customized or is missing important files.'
exit 0;
#	else
#		echo "$FILE found.";
fi
done

echo"";
echo "";


echo "Checking for important directories in /old and current root...";
sleep 2;
for DIRECTORY in ${IMPORTANT_DIRECTORIES[@]}
do

if [ ! -d ${RESTORE_DIR}${DIRECTORY} ]; then
echo "${RESTORE_DIR}$DIRECTORY not found!!";
echo 'Unable to continue automatically.  Server back-up incomplete or original server was customized.'
exit 0;
#	else
#		echo "${RESTORE_DIR}$DIRECTORY found.";
fi

if [ ! -d ${DIRECTORY} ]; then
echo "$DIRECTORY not found.";
echo 'Unable to continue automatically.  Current server was customized or is missing important files.'
exit 0;
#	else
#		echo "$DIRECTORY found.";
fi
done


##Checking password file; we will be partially restoring for anything bad.
echo;
echo;


echo 'Checking old password file for suspicious users.';
sleep 2;

##First, we look for root alias accounts.

ROOTALIAS=( $(awk -F: '$3 ~/^0$/ && $1 !~/^root$/' ${RESTORE_DIR}/etc/passwd) ) ;

if [ ${#ROOTALIAS[@]}  -ge  1  ]; then
echo "Found root aliases..."
for FOUND in  ${ROOTALIAS[@]}
do
echo "Found $FOUND.";
done
echo "Generally, this is a bad thing.  Please remove these users from the old password file before restoring.";
echo "Restore aborted.";
exit 0
else
echo "No root aliases found.";

fi
echo;

##Next, we look for shell users that do not appear to have been added by Plesk. Remember '/bin/false' shell allows for FTP login and SSH proxy.

CUSTOMUSERS=( $(awk -F: '$3 !~/^0$/ &&  $6 !~/\/var\/www\/vhosts/ && $1 !~/^(mysql)$/ && $7 ~/sh$|\/bin\/false$/' ${RESTORE_DIR}/etc/passwd ) );

if [ ${#CUSTOMUSERS[@]}  -ge  1  ]; then
echo "Found custom users..."
for FOUND in  ${CUSTOMUSERS[@]}
do
echo "Found $FOUND.";
done
read -p 'Are these legitimate users you added to the system? (Remember "/bin/false" shell allows for FTP login and SSH proxy.)   YES/no : ' USERANSWER
if [ "$USERANSWER" != "YES"  ]; then
echo "Please remove these users from the old password file before restoring.";
echo "Restore aborted.";
exit 0
fi
else
echo "No custom users found.";

fi
sleep 2;
echo


echo 'Checking for root owned files in web viewable directies.....';
sleep 2;
ROOTFILE=( $( cd ${RESTORE_DIR}/var/www/vhosts ;  find */httpdocs/ */httpsdocs/ */cgi-bin/  -user root ! -regex .*plesk-stat.*  ) );

if  [ ${#ROOTFILE[@]} -ge 1  ]; then
echo "Found root owned files in web viewable directories...."
for FOUND in ${ROOTFILE[@]}
do
echo "$FOUND";
done
read -p 'Are these legitimate root owned files? YES/no : ' ROOTFILEANSWER
if [ "$ROOTFILEANSWER" != "YES"  ]; then
echo "Please remove these files before restoring.";
echo "Restore aborted.";
exit 0
fi
else
echo "No root files found in web viewable directories.";


fi

echo "";
echo "";


echo "Checking for suspicious crontabs...";
sleep 2
for CRONT in $(ls -1 ${RESTORE_DIR}/var/spool/cron)
do
echo "crontab for $CRONT";
cat ${RESTORE_DIR}/var/spool/cron/$CRONT;
echo;
done

read -p 'Any suspicious crontab entries? yes/NO : ' ANSWERCRON
if [ "$ANSWERCRON" != "NO"   ]; then
echo 'Please remove the suspicious entries, then re-run this script.';
exit 0;
fi

echo "Pre-cehck complete. Creating back-up directories....."
sleep 2;

##Creating back up directories for current files on the newly restored (dv).

echo "";
echo "";
if [ ! -d ${BACKUP_DIR} ]; then
mkdir ${BACKUP_DIR};
echo "Created ${BACKUP_DIR}";
else
echo "${BACKUP_DIR} already exists.";
fi

for BACKUP_DIR_C in  ${BACKUP_DIRS[@]}
do
if [ ! -d ${BACKUP_DIR}${BACKUP_DIR_C} ]; then
mkdir ${BACKUP_DIR}$BACKUP_DIR_C;
echo "Created ${BACKUP_DIR}$BACKUP_DIR_C";

else
FOUND='set';
#		echo "${BACKUP_DIR}$BACKUP_DIR_C already exists.";
fi
done
#sleep 2;
echo '';
if [ "$FOUND" == "set"  ]; then
read -p 'Possible pre-existing back-up. Do you want to move the older back-up and continue? YES/no : ' ANSWER
if [ "$ANSWER" != "YES"  ]; then
echo "Your response was 'no.' Restore aborted. Please move or remove existing back-up directory or change \$BACKUP_DIR variable.";
exit 0
else
DATE=$( date | sed -e "s/\ /_/g" );
mv ${BACKUP_DIR} ${BACKUP_DIR}${DATE};
mkdir ${BACKUP_DIR}
echo "Old back up saved in /opt/mt_restore_backup${DATE}";
for BACKUP_DIR_C in  ${BACKUP_DIRS[@]}
do
mkdir ${BACKUP_DIR}${BACKUP_DIR_C};
echo "Created ${BACKUP_DIR}${BACKUP_DIR_C}";
done

echo "Back-up directories ready. Copying files...";
fi
else
echo "Back-up directories ready. Copying files....";
fi

echo '';

##copying over files to back up directories

echo 'Saving system user files...';
cp -p /etc/passwd /etc/group /etc/shadow ${BACKUP_DIR}/etc/;

echo 'Saving vhosts directories...';
cp -Rdp /var/www/vhosts/* ${BACKUP_DIR}/vhosts;

echo 'Saving qmail files...';
/etc/init.d/qmail stop;
cp -Rdp /var/qmail/* ${BACKUP_DIR}/qmail;
/etc/init.d/qmail start;


echo 'Saving bind files...';
cp -Rdp /var/named/run-root/etc/* ${BACKUP_DIR}/run-root;
cp -Rdp /var/named/run-root/var/* ${BACKUP_DIR}/run-root;

echo 'Saving Plesk Apache config...';
cp -p /etc/httpd/conf.d/zz010_psa_httpd.conf ${BACKUP_DIR}/conf.d/;

echo 'Saving phpMyAdmin config...';
cp -p /usr/local/psa/admin/htdocs/domains/databases/phpMyAdmin/libraries/config.default.php ${BACKUP_DIR}/PSAphpMyAdmin/;

if [ -f /etc/psa/.webmail.shadow ]; then
	echo 'Saving Horde config...';
	cp -Rdp /etc/psa-horde/* ${BACKUP_DIR}/webmail;
	cp /etc/psa/.webmail.shadow ${BACKUP_DIR}/webmail/;
elif [ -d /etc/psa-webmail ]; then
	echo 'Saving Horde and Atmail config...';
	cp -Rdp /etc/psa-webmail/* ${BACKUP_DIR}/webmail;
fi

echo 'Saving certificate files...';
cp -p /usr/local/psa/var/certificates/* ${BACKUP_DIR}/certificates/;

echo 'Saving crontabs...';
cp -dp /var/spool/cron/* ${BACKUP_DIR}/crons;

echo 'Saving MySQL databases...';
/etc/init.d/mysqld stop;
cp -Rdp /var/lib/mysql/* ${BACKUP_DIR}/mysql;
/etc/init.d/mysqld start;

echo 'Saving psa shadow file...';
cp -p /etc/psa/.psa.shadow ${BACKUP_DIR}/;

echo 'Saving psa dump files...';
touch /var/lib/psa/dumps/place_holder;
cp -Rdp /var/lib/psa/dumps/* ${BACKUP_DIR}/dumps;

echo 'Saving psa application files...';
cp -Rdp /usr/local/psa/var/apspackages ${BACKUP_DIR}/;

echo 'Saving psa admin generated configuration includes...';
cp -Rdp /usr/local/psa/admin/conf/generated ${BACKUP_DIR}/;

read -p 'Back-ups complete. Ready for final sync? (You may want to double-check that the script backed up the current config correctly.)  YES/no : ' ANSWERTWO
if [ "$ANSWERTWO" != "YES"  ]; then
echo "Your response was 'no.' Restore aborted.";
exit 0
else
echo "Syncing with ${RESTORE_DIR} files...";
fi


##Contructing new system user files which will be a combination of the one in the /old and the current one since Plesk does not keep some important uid's and gid's consistant.  If we didn't do this, Plesk may encounter errors

echo "Syncing system users (except root) ..."
echo "Creating new password file in /tmp...";
sed -e  "s/^psaadm:.*$/$(cat ${BACKUP_DIR}/etc/passwd | egrep ^psaadm: | sed -e  s'/\//\\\//g' )/" \
-e  "s/^psaftp:.*$/$(cat ${BACKUP_DIR}/etc/passwd | egrep ^psaftp: | sed -e  s'/\//\\\//g' )/"  ${RESTORE_DIR}/etc/passwd > /tmp/.newpasswdf;


echo "Creating new group file in /tmp...";
sed -e  "s/^psaadm:.*$/$(cat ${BACKUP_DIR}/etc/group | egrep ^psaadm: | sed -e  s'/\//\\\//g' )/"  \
-e  "s/^psaftp:.*$/$(cat ${BACKUP_DIR}/etc/group | egrep ^psaftp: | sed -e  s'/\//\\\//g' )/"  \
-e  "s/^psaserv:.*$/$(cat ${BACKUP_DIR}/etc/group | egrep ^psaserv: | sed -e  s'/\//\\\//g' )/" \
-e  "s/^psacln:.*$/$(cat ${BACKUP_DIR}/etc/group | egrep ^psacln: | sed -e  s'/\//\\\//g' )/" ${RESTORE_DIR}/etc/group > /tmp/.newgroupf;


echo "Creating new shadow file in /tmp...";
sed "s/^root:.*$/$(cat ${BACKUP_DIR}/etc/shadow | egrep ^root: | sed -e s'/\//\\\//g')/" ${RESTORE_DIR}/etc/shadow > /tmp/.newshadowf;

read -p 'Review tmp sys user files?  yes/NO : ' ANSWERTHREE
if [ "$ANSWERTHREE" != "NO"  ]; then
echo "Your response was 'yes.' Restore aborted.";
exit 0;
else
echo "Syncing with /tmp files...";
fi

##Syncing the tmp new system user database files with active database files and cleaning up the tmp files.

cat /tmp/.newpasswdf > /etc/passwd;
cat /tmp/.newgroupf > /etc/group;
cat /tmp/.newshadowf > /etc/shadow;
rm -f /tmp/.newpasswdf /tmp/.newgroupf /tmp/.newshadowf;



##Syncing everything else with /old.


echo 'Syncing vhosts...';
/bin/cp -Rdpf ${RESTORE_DIR}/var/www/vhosts/* /var/www/vhosts;

##Fixing the mixed up psa* groups.
echo 'Correcting folder owners...';
find /var/www/vhosts/  -gid $( awk -F: '$1 ~/^psaserv$/ {print $3}' ${RESTORE_DIR}/etc/group ) -exec chgrp -h psaserv {} \; ;
find /var/www/vhosts/ -gid $( awk -F: '$1 ~/^psacln$/ {print $3}' ${RESTORE_DIR}/etc/group  ) -exec chgrp -h psacln {} \; ;
for PSAUSER in $(awk -F: '$6 ~/\/var\/www\/vhosts/{print $1}' /etc/passwd );
do
usermod -g psacln $PSAUSER;
done

##Simple copying of everything else
echo 'Syncing qmail files...';
/etc/init.d/qmail stop;
/bin/cp -Rdpf ${RESTORE_DIR}/var/qmail/alias/* /var/qmail/alias/;
/bin/cp -Rdpf ${RESTORE_DIR}/var/qmail/boot/* /var/qmail/boot/;
/bin/cp -Rdpf ${RESTORE_DIR}/var/qmail/control/* /var/qmail/control/;
/bin/cp -Rdpf ${RESTORE_DIR}/var/qmail/mailnames/* /var/qmail/mailnames/;
/bin/cp -Rdpf ${RESTORE_DIR}/var/qmail/plugins/* /var/qmail/plugins/;
/bin/cp -Rdpf ${RESTORE_DIR}/var/qmail/queue/* /var/qmail/queue/;
/bin/cp -Rdpf ${RESTORE_DIR}/var/qmail/users/* /var/qmail/users/;

echo 'Syncing bind files...';
/bin/cp -Rdpf ${RESTORE_DIR}/var/named/run-root/etc/* /var/named/run-root/etc
/bin/cp -Rdpf ${RESTORE_DIR}/var/named/run-root/var/* /var/named/run-root/var

echo 'Syncing Plesk Apache config...';
cat ${RESTORE_DIR}/etc/httpd/conf.d/zz010_psa_httpd.conf > /etc/httpd/conf.d/zz010_psa_httpd.conf;

echo 'Syncing phpMyAdmin config...';
cat ${RESTORE_DIR}/usr/local/psa/admin/htdocs/domains/databases/phpMyAdmin/libraries/config.default.php > /usr/local/psa/admin/htdocs/domains/databases/phpMyAdmin/libraries/config.default.php

if [ -f /etc/psa/.webmail.shadow ]; then
	echo 'Syncing Horde config...';
	cp -Rdpf ${RESTORE_DIR}/etc/psa-horde/* /etc/psa-horde
	cat ${RESTORE_DIR}/etc/psa/.webmail.shadow > /etc/psa/.webmail.shadow;
elif [ -d /etc/psa-webmail ]; then
	echo 'Syncing Horde and Atmail config...';
	cp -Rdpf ${RESTORE_DIR}/etc/psa-webmail/* /etc/psa-webmail;
fi

echo 'Syncing Certificate files...';
rm -f /usr/local/psa/var/certificates/*;
cp -dpf ${RESTORE_DIR}/usr/local/psa/var/certificates/* /usr/local/psa/var/certificates;

echo 'Syncing crontabs...';
/bin/cp -pf ${RESTORE_DIR}/var/spool/cron/* /var/spool/cron;

echo 'Syncing databases...';
/etc/init.d/mysqld stop;
rm -rf /var/lib/mysql/*;
/bin/cp -Rdpf ${RESTORE_DIR}/var/lib/mysql/* /var/lib/mysql;

echo 'Syncing psa applications...';
cp -Rdpf ${RESTORE_DIR}/usr/local/psa/var/apspackages/* /usr/local/psa/var/apspackages;

echo 'Syncing psa admin generated configuration includes...';
cp -Rdpf ${RESTORE_DIR}/usr/local/psa/admin/conf/generated/* /usr/local/psa/admin/conf/generated;

echo 'Syncing Plesk admin pass...';
cat ${RESTORE_DIR}/etc/psa/.psa.shadow > /etc/psa/.psa.shadow;

echo 'Syncing Plesk dump files...';
touch ${RESTORE_DIR}/var/lib/psa/dumps/place_holder;
cp -Rdpf ${RESTORE_DIR}/var/lib/psa/dumps/* /var/lib/psa/dumps;
#fixing dump file owners
find /var/lib/psa/dumps/ -uid $( awk -F: '$1 ~/^psaadm$/ {print $3}' ${RESTORE_DIR}/etc/passwd  ) -exec chown psaadm:psaadm {} \; ;


echo '';
echo '';
echo 'If you only saw two errors about a special file, you should be good!';
echo '';
echo '';
echo 'Restarting services...';
/etc/init.d/mysqld start;
/etc/init.d/httpd restart;
/etc/init.d/qmail start;
/etc/init.d/xinetd restart;
/etc/init.d/courier-imap restart;
/etc/init.d/named restart;
/etc/init.d/psa restart;
/usr/local/psa/admin/sbin/mchk --with-spam;
echo '';
echo 'Rebuilding Plesk configuration with the "web" command';
/usr/local/psa/admin/sbin/httpdmng --reconfigure-all;
echo 'Restore complete.  RESET PLESK ADMIN PASSWORD ASAP!!!';
