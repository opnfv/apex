#!/bin/sh
# Script 4 - Build the lsoapi code

echo "Started building lsoapi code" >>  $HOME/mdsal_ansible/install.log
cd $HOME/mdsal_ansible/lsoapi
mvn clean install >> $HOME/mdsal_ansible/lsoapi.log
echo "lsoapi code built" >>  $HOME/mdsal_ansible/install.log
