#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
force=$1
if [[ "x"$force == "x-f" ]]; then
    force=1
fi

. $basepath/env.sh
basepath=$(cd `dirname $0`; pwd)
sourcepath=$(cd `dirname $0`/../; pwd)
cd $basepath

if [[ $TEST_DATABASE ]]; then
    echo "存在"
else
    echo "不存在"
fi

echo "start base64 decode"
echo $TEST_DATABASE | base64 -di > $sourcepath/tapshell/test/.env
echo "end base64 decode"
ls -al $sourcepath/tapshell/test/

if [[ $force -eq 1 ]]; then
    docker rm -f $dev_container_name
    docker rmi -f `cat image/tag`
fi

docker ps|grep $dev_container_name &> /dev/null
if [[ $? -ne 0 ]]; then
    tag=`cat image/tag`
    x=`docker images $tag|wc -l`
    if [[ $x -eq 1 ]]; then
        cd ../
        bash build/build.sh -c iengine
        bash build/build.sh -c manager
        bash build/build.sh -c plugin-kit
        bash build/build.sh -c connectors
        bash build/build.sh -p 1 -o image
    fi
    cd $basepath
    docker run -e mode=test -p 13000:3000 -p 27017:27017 -v $sourcepath:/tapdata-source/ -i --name=$dev_container_name `cat image/tag` bash
    if [[ $? -ne 0 ]]; then
        exit 127
    fi
fi
