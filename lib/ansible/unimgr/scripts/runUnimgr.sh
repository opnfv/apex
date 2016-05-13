#!/bin/sh
# Script 6 - Make changes for the IP address and MAC address, build lsoapi and unimgr code and start the UI and karaf 

cd $HOME/mdsal_ansible/lsoapi/demo-ui
bower --allow-root install >>  $HOME/mdsal_ansible/lsoapi.log
grunt >>  $HOME/mdsal_ansible/lsoapi.log
cd app
#Change to appropriate IPs of Pis here
sed -i 's/10.0.0.21/{{ ip1 }}/g; s/10.0.0.22/{{ ip2 }}/g;'  $HOME/mdsal_ansible/lsoapi/demo-ui/app/config.json

#Change to appropriate mac of Pis here
sed -i 's/b8:27:eb:6a:e0:60/{{ mac1 }}/g; s/b8:27:eb:26:b1:c8/{{ mac2 }}/g;'  $HOME/mdsal_ansible/lsoapi/demo-ui/app/config.json
cd ..
nohup node vcpeUiServer.js &
echo "UI started" >>  $HOME/mdsal_ansible/install.log

touch $HOME/mdsal_ansible/build.log

cd $HOME/mdsal_ansible/unimgr
git checkout stable/beryllium
mvn -DskipTests clean install >> $HOME/mdsal_ansible/build.log

cd karaf/target
tar xf unimgr-karaf-0.0.1-SNAPSHOT.tar.gz
nohup ./unimgr-karaf-0.0.1-SNAPSHOT/bin/karaf &

echo "The controller is setup" >> $HOME/mdsal_ansible/install.log

