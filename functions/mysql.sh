#!/bin/bash

# This file contains the functions to set up mysql-server and create the vmail DB

# Generate a MySQL password for the VMailUser
export DB_USER="VMailUser"
export VMAIL_PWD="$(date +%N%s | sha256sum | head -c${1:-12})"

mk_db () {
    TMP_FILE="$(mktemp)"
    echo "Creating Database"
    echo "CREATE DATABASE VMail;
        CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$VMAIL_PWD';
        GRANT ALL PRIVILEGES ON VMail.* TO 'VMailUser'@'localhost';
        FLUSH PRIVILEGES;" > $TMP_FILE  
    mysql < $TMP_FILE
    rm $TMP_FILE
}

create_tables () {
    # Follows the structure of:
    # https://www.linode.com/docs/email/postfix/email-with-postfix-dovecot-and-mysql/
    echo "Creating tables"
    TMP_FILE="$(mktemp)"
    echo "CREATE TABLE `virtual_domains` (
          `id` int(11) NOT NULL auto_increment,
          `name` varchar(50) NOT NULL,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
        
        CREATE TABLE `virtual_users` (
          `id` int(11) NOT NULL auto_increment,
          `domain_id` int(11) NOT NULL,
          `password` varchar(106) NOT NULL,
          `email` varchar(100) NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `email` (`email`),
          FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
        
        CREATE TABLE `virtual_aliases` (
          `id` int(11) NOT NULL auto_increment,
          `domain_id` int(11) NOT NULL,
          `source` varchar(100) NOT NULL,
          `destination` varchar(100) NOT NULL,
          PRIMARY KEY (`id`),
          FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;" > $TMP_FILE
    mysql -u $DB_USER -p$VMAIL_PWD VMail < $TMP_FILE
}

save_pwd () {
    touch /root/.vmail_db_pass
    echo $VMAIL_PWD > /root/.vmail_db_pass
    unset VMAIL_PWD
    echo "Saved the paasword to /root/.vmail_db_pass"
}