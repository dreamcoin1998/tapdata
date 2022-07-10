#!/bin/bash
. $basepath/env.sh
basepath=$(cd `dirname $0`; pwd)
sourcepath=$(cd `dirname $0`/../; pwd)
cd $basepath

bash build/build.sh -p 1 -o image
docker run -e mode=test -p 13000:3000 -p 27017:27017 -v $sourcepath:/tapdata-source/ -i --name=$dev_container_name `cat image/tag` bash
exit $?
