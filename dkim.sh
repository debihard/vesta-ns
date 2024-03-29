#!/bin/bash
# info: add mail domain dkim support
# options: USER DOMAIN [DKIM_SIZE]
#
# The function adds DKIM signature to outgoing domain emails.


#----------------------------------------------------------#
#                    Variable&Function                     #
#----------------------------------------------------------#

# Argument defenition
user=$1
domain=$(idn -t --quiet -u "$2" )
domain=$(echo $domain | tr '[:upper:]' '[:lower:]')
domain_idn=$(idn -t --quiet -a "$domain")
dkim_size=${3-1024}

# Includes
source $VESTA/func/main.sh
source $VESTA/func/domain.sh
source $VESTA/conf/vesta.conf

# Define mail user
if [ "$MAIL_SYSTEM" = 'exim4' ]; then
    MAIL_USER=Debian-exim
else
    MAIL_USER=exim
fi


#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

check_args '2' "$#" 'USER DOMAIN [DKIM_SIZE]'
is_format_valid 'user' 'domain' 'dkim_size'
is_system_enabled "$MAIL_SYSTEM" 'MAIL_SYSTEM'
is_object_valid 'user' 'USER' "$user"
is_object_unsuspended 'user' 'USER' "$user"
is_object_valid 'mail' 'DOMAIN' "$domain"
is_object_unsuspended 'mail' 'DOMAIN' "$domain"
is_object_value_empty 'mail' 'DOMAIN' "$domain" '$DKIM'


#----------------------------------------------------------#
#                       Action                             #
#----------------------------------------------------------#

# Generating dkim
openssl genrsa -out $USER_DATA/mail/$domain.pem $dkim_size &>/dev/null
openssl rsa -pubout -in $USER_DATA/mail/$domain.pem \
    -out $USER_DATA/mail/$domain.pub &>/dev/null
chmod 660 $USER_DATA/mail/$domain.*

# Adding dkim keys
if [[ "$MAIL_SYSTEM" =~ exim ]]; then
    cp $USER_DATA/mail/$domain.pem $HOMEDIR/$user/conf/mail/$domain/dkim.pem
    chown $MAIL_USER:mail $HOMEDIR/$user/conf/mail/$domain/dkim.pem
    chmod 660 $HOMEDIR/$user/conf/mail/$domain/dkim.pem
fi

# Adding dns records
if [ ! -z "$DNS_SYSTEM" ] && [ -e "$USER_DATA/dns/$domain.conf" ]; then
    p=$(cat $USER_DATA/mail/$domain.pub |grep -v ' KEY---' |tr -d '\n')
    record='_domainkey'
    policy="\"t=y; o=~;\""
    $BIN/v-add-dns-record $user $domain $record TXT "$policy"

    record='mail._domainkey'
    selector="\"k=rsa\; p=$p\""
    $BIN/v-add-dns-record $user $domain $record TXT "$selector"
fi


#----------------------------------------------------------#
#                       Vesta                              #
#----------------------------------------------------------#

# Adding dkim in config
update_object_value 'mail' 'DOMAIN' "$domain" '$DKIM' 'yes'
increase_user_value "$user" '$U_MAIL_DKMI'

# Logging
log_history "enabled DKIM support for $domain"
log_event "$OK" "$EVENT"

exit
