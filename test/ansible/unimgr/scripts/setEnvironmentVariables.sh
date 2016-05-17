#!/bin/sh
# Script 1 - Set the environment variables for the project

echo "export M2_HOME=/opt/maven/apache-maven-3.3.3" >> $HOME/.bashrc
echo "export MAVEN_OPTS='-Xmx2048m -XX:MaxPermSize=1024m'" >> $HOME/.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.95-2.6.4.0.el7_2.x86_64" >> $HOME/.bashrc
echo "export CATALINA_HOME=/usr/local/apache-tomcat/apache-tomcat-8.0.24" >> $HOME/.bashrc
echo "done executing" >> $HOME/environment.log