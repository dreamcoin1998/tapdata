#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
sourcepath=$(cd `dirname $0`/../; pwd)

. $basepath/env.sh

cd $sourcepath
bash build/build.sh -c plugin-kit
bash build/build.sh -p 1 -o image
cd $basepath
docker run -e mode=test -p 13000:3000 -p 27017:27017 -v $sourcepath:/tapdata-source/ -i --name=$dev_container_name `cat image/tag` bash
if [[ $? -ne 0 ]]; then
    exit 127
fi
