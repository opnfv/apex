#!/usr/bin/env bash
echo "Installing apache-maven-3.3.3" >> ~/mdsal_ansible/install.log
mkdir ~/mdsal_ansible
mkdir ~/mdsal_ansible/Downloads
cd ~/mdsal_ansible/Downloads
wget http://ftp.wayne.edu/apache/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz
mkdir /opt/maven
tar -xzvf ~/mdsal_ansible/Downloads/apache-maven-3.3.3-bin.tar.gz
mv apache-maven-3.3.3 /opt/maven
ln -s /opt/maven/apache-maven-3.3.3/bin/mvn /usr/bin/mvn

cd ~

wget https://raw.githubusercontent.com/opendaylight/odlparent/master/settings.xml

if [ ! -d ~/.m2/ ]; then
    mkdir ~/.m2/
fi

cp settings.xml ~/.m2/