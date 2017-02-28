#!/usr/bin/env bash
JARS=$(find /usr/share/java/ -type f -iname 'jvpp-*.jar')
if [ -z "$JARS" ]; then
  echo "ERROR: JARS to replace from vpp-api-java are empty!"
  exit 1
fi

for JAR in $JARS; do
  JAR_PREFIX=$(basename $JAR | sed -n 's/-[0-9]\+\.[0-9]\+\.jar$//p')
  JAR_VERSION=$(basename $JAR | grep -Eo '[0-9]+.[0-9]+')
  HC_JAR_DIR=/opt/honeycomb/lib/io/fd/vpp/${JAR_PREFIX}/${JAR_VERSION}-SNAPSHOT
  if [ ! -d "$HC_JAR_DIR" ]; then
    echo "ERROR: Honeycomb JAR destination directory does not exist!"
    exit 1
  else
    cp -f ${JAR} ${HC_JAR_DIR}/${JAR_PREFIX}-${JAR_VERSION}-SNAPSHOT.jar
    echo "INFO: VPP API JAR: ${JAR} copied to ${HC_JAR_DIR}"
  fi
done
