#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
sourcepath=$(cd `dirname $0`/../; pwd)
. $basepath/env.sh
cd $sourcepath

ls -al

mv dist/ ./

bash build/build.sh -p 1 -o image
docker run -e mode=test -p 13000:3000 -p 27017:27017 -v $sourcepath:/tapdata-source/ -i --name=$dev_container_name `cat image/tag` bash
exit $?
