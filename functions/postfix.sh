#!/bin/bash

postfix_main_cf () {
    # NOTE ON POSTCONF COMMANDS

    # The `postconf` command literally just adds the line in question to
    # /etc/postfix/main.cf so if you need to debug something, go there. It replaces
    # any other line that sets the same setting, otherwise it is appended to the
    # end of the file.

    echo "Configuring Postfix's main.cf..."

    # Change the cert/key files to the default locations of the Let's Encrypt cert/key
    postconf -e "smtpd_tls_key_file=$certdir/privkey.pem"
    postconf -e "smtpd_tls_cert_file=$certdir/fullchain.pem"
    postconf -e "smtpd_use_tls = yes"
    postconf -e "smtp_tls_security_level = may"
    postconf -e "smtp_tls_loglevel = 1"
    # From mozzilla tls config tool
    postconf -e "smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache"
    postconf -e "smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache"
    postconf -e "smtpd_tls_security_level = may"
    postconf -e "smtpd_tls_auth_only = yes"
    postconf -e "smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
    postconf -e "smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
    postconf -e "smtpd_tls_mandatory_ciphers = medium"
    postconf -e "tls_medium_cipherlist = ECDHE-ECDSA-AES128-GCM-SHA256:\
                ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:\
                ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:\
                ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:\
                DHE-RSA-AES256-GCM-SHA384"

    # Here we tell Postfix to look to Dovecot for authenticating users/passwords.
    # Dovecot will be putting an authentication socket in /var/spool/postfix/private/auth
    postconf -e "smtpd_sasl_auth_enable = yes"
    postconf -e "smtpd_sasl_type = dovecot"
    postconf -e "smtpd_sasl_path = private/auth"

    # Disable VRFY command
    postconf -e "disable_vrfy_command = yes"

    #postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination"

    # Use LMTP to deliver the mail to dovecot
    postconf -e "virtual_transport = lmtp:unix:private/dovecot-lmtp"

    # Virtual domains, users, and aliases
    postconf -e "virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf"
    postconf -e "virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf"
    postconf -e "virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf, mysql:/etc/postfix/mysql-virtual-email2email.cf"


    # NOTE: the trailing slash here, or for any directory name in the home_mailbox
    # command, is necessary as it distinguishes a maildir (which is the actual
    # directories that what we want) from a spoolfile (which is what old unix
    # boomers want and no one else).
    #postconf -e "home_mailbox = Mail/Inbox/"

    # Research this one:
    #postconf -e "mailbox_command ="
}

postfix_master_cf () {
    # master.cf

    echo "Configuring Postfix's master.cf..."

    sed -i "/^\s*-o/d;/^\s*submission/d;/^\s*smtp/d" /etc/postfix/master.cf

    echo "smtp unix - - n - - smtp
    smtp inet n - y - - smtpd
    -o content_filter=spamassassin
    submission inet n       -       y       -       -       smtpd
    -o syslog_name=postfix/submission
    -o smtpd_tls_security_level=encrypt
    -o smtpd_sasl_auth_enable=yes
    -o smtpd_tls_auth_only=yes
    smtps     inet  n       -       y       -       -       smtpd
    -o syslog_name=postfix/smtps
    -o smtpd_tls_wrappermode=yes
    -o smtpd_sasl_auth_enable=yes
    spamassassin unix -     n       n       -       -       pipe
    user=debian-spamd argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f \${sender} \${recipient}" >> /etc/postfix/master.cf
}