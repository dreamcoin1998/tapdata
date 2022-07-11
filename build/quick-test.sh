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

if [[ $force -eq 1 ]]; then
    docker rm -f $dev_container_name
    docker rmi -f `cat image/tag`
fi

nohup bash ./pre.sh -t image -m $docker_all_in_one &> $docker_all_in_one.log &
nohup bash ./pre.sh -t image -m $docker_build &> $docker_build.log &
nohup bash ./pre.sh -t image -m $docker_runtime &> $docker_runtime.log &

sleep 1

for i in $(seq 1 300); do
    if [[ -f $docker_all_in_one.log && -f $docker_build.log && -f $docker_runtime.log && ! -f $docker_all_in_one.run && ! -f $docker_build.run && ! -f $docker_runtime.run ]]; then
      info "this is $docker_all_in_one.log"
      cat $docker_all_in_one.log
      info "this is $docker_build.log"
      cat $docker_build.log
      info "this is $docker_runtime.log"
      cat $docker_runtime.log
      break
    else
      info "pulling images"
    fi
    sleep 1
done

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
