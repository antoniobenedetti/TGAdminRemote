#!/bin/bash
#
# GamePanelX Pro
# Remote v1.0.5
#
# Installation Script
#
# Licensed under the GPL (GNU General Public License V3)
#
echo "##################################################################"
echo "##                                                              ##"
echo "##                        GamePanelX Pro                        ##"
echo "##                                                              ##"
echo "##         Welcome to the Remote Server installer (v1.0.5)      ##"
echo "##                                                              ##"
echo "##################################################################"
echo

if [ "$UID" -ne "0" ]
then
    echo "ERROR: You must be the root user to run this script.  Exiting."
    exit
fi

read -p "Create this Linux user for game/voice servers: " gpx_user
read -p "Master Server MySQL IP Address: " gpx_master_ip
read -p "Master Server MySQL Port: " gpx_master_mysql_port
read -p "Master Server MySQL Database Name: " gpx_master_mysql_db
read -p "Master Server MySQL Database Username: " gpx_master_mysql_user
read -p "Master Server MySQL Database Password: " gpx_master_mysql_pass

echo
echo "##################################################################"
echo

# Check if user already exists
if [ "`cat /etc/passwd | awk -F: '{print $1}' | grep $gpx_user`" ]
then
    echo "ERROR: That user already exists.  Please choose a different username and try again.  Exiting."
    exit
fi

if [[ "$gpx_user" == "" || "$gpx_master_ip" == "" || "$gpx_master_mysql_port" == "" || "$gpx_master_mysql_db" == "" || "$gpx_master_mysql_user" == "" || "$gpx_master_mysql_pass" == "" ]]
then
    echo "You left out required fields, exiting."
    exit
fi

read -p "OK!  We will now install the system user and FTP Server.  Is that OK? (y/n): " gpx_accept

if [ "$gpx_accept" == "" ]
then
    echo "Exiting."
    exit
fi

if [[ "$gpx_accept" == "y" || "$gpx_accept" == "yes" ]]
then
    # Create the gpx user
    useradd -m -c "GPX Pro User" -s /bin/bash $gpx_user
    gpx_user_home=`eval echo ~$gpx_user`
    
    # Get UID and GID
    avail_uid="`grep $gpx_user /etc/passwd | awk -F: '{print $3}'`"
    avail_gid="`grep $gpx_user /etc/group | awk -F: '{print $3}'`"
    
    # Make sure we found them
    if [[ "$avail_uid" == "" || "$avail_gid" == "" ]]
    then
        echo "ERROR: User creation failed!  Unable to find the UID or GID of the user."
        exit
    fi
    
    # Make sure homedir exists
    if [ ! -d "$gpx_user_home" ]
    then
        echo "ERROR: Failed to find the users homedir!  Exiting."
        exit
    fi
    
    # Untar the Remote files
    if [ -f "./gpx-remote-latest.tar.gz" ]
    then
        tar -zxf ./gpx-remote-latest.tar.gz -C $gpx_user_home/
    else
        echo "ERROR: Latest remote server files (gpx-remote-latest.tar.gz) not found!  Try re-downloading the remote files and try again.  Exiting."
        exit
    fi
    
    # Change ownership of all the new files
    chown $gpx_user:$gpx_user $gpx_user_home
    chown $gpx_user:$gpx_user $gpx_user_home -R
    
    # Prepare FTP Server
    rm -fr ./gpx_tmp_ftpinstall
    mkdir ./gpx_tmp_ftpinstall
    cd ./gpx_tmp_ftpinstall
    wget http://files.gamepanelx.com/gpxpro-ftpd-latest.tar.gz
    sleep 1

    if [ ! -f ./gpxpro-ftpd-latest.tar.gz ]
    then
        echo "ERROR: Failed to download the latest FTP Server files!  Exiting."
        exit
    fi
    
    # Compile FTP Server
    tar -zxf gpxpro-ftpd-latest.tar.gz
    cd gpxpro-ftpd-latest
    ./configure --prefix=$gpx_user_home/ftpd --with-puredb --with-extauth --with-throttling --with-ratios --with-virtualhosts --with-peruserlimits --with-everything --with-mysql
    sleep 1
    make
    sleep 1
    make install

    ################

    if [ ! -f "$gpx_user_home/ftpd/sbin/pure-ftpd" ]
    then
        echo "ERROR: No FTPd binary found; installation failed.  Check above for why the FTP installation failed. Exiting."
        exit
    fi

    ################
    
    # Setup MySQL for FTP Server
    echo -e "MYSQLSocket             /tmp/mysql.sock
MYSQLServer             $gpx_master_ip
MYSQLPort               $gpx_master_mysql_port
MYSQLUser               $gpx_master_mysql_user
MYSQLPassword           $gpx_master_mysql_pass
MYSQLDatabase           $gpx_master_mysql_db
MYSQLCrypt              md5
MYSQLGetPW              SELECT password FROM clients WHERE username='\L' AND status='active'
MYSQLGetDir             SELECT CONCAT(p2.accounts_dir, '/\L/') AS accounts_dir FROM network p1 JOIN network p2 ON p1.parentid = p2.id WHERE p1.ip = '\I' OR p2.ip='\I' LIMIT 0,1
MYSQLDefaultUID         $avail_uid
MYSQLDefaultGID         $avail_gid" > $gpx_user_home/ftpd/mysql.conf

    ################

    # Create startup script
    echo "#!/bin/bash" > $gpx_user_home/ftpd/start.sh
    echo "$gpx_user_home/ftpd/sbin/pure-ftpd -A -B -C 5 -c 150 -E -H -R -x -X -d -j -l mysql:$gpx_user_home/ftpd/mysql.conf" >> $gpx_user_home/ftpd/start.sh
    chmod u+x $gpx_user_home/ftpd/start.sh

    # Start the FTP Server
    back_wd=`pwd`
    cd $gpx_user_home/ftpd/
    ./start.sh
    sleep 1
    cd $back_wd

    ################

    echo
    echo
    echo
    echo
    echo "##################################################################"
    echo
    echo "Finished Installing the system user and FTP Server."
    echo
    echo "##################################################################"
    echo
    echo "Enter a password for user $gpx_user ..."
    passwd $gpx_user

    echo
    echo
    echo "##################################################################"
    echo
    echo "NOTE: In order for the FTP Server to use your Master Server database, "
    echo "you must grant priviliges to this server IP using the root mysql user. "
    echo "See the following link: "
    echo "http://gamepanelx.com/docs/index.php?title=Remote_Server_Installation#Master_Database_Privileges "
    echo
    echo
    echo "SUCCESS!  Successfully installed the Remote Server.  Exiting."
    echo
    exit
fi
