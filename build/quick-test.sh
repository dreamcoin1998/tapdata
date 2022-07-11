#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
sourcepath=$(cd `dirname $0`/../; pwd)
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

nohup bash ./pre.sh -t image -m $docker_all_in_one &> $sourcepath/$docker_all_in_one.log &
nohup bash ./pre.sh -t image -m $docker_build &> $sourcepath/$docker_build.log &
nohup bash ./pre.sh -t image -m $docker_runtime &> $sourcepath/$docker_runtime.log &

sleep 1

wait_run() {
  cd $sourcepath
  for i in $(seq 1 300); do
    is_ok=0
    for m in "$*"; do
      if [[ -f $m.log && ! -f $m.run ]]; then
        continue
      else
        line_log=`tail -1 $m.log`
        echo "line log belong to: $line_log"
        is_ok=1
        break
      fi
    done
    if [[ $is_ok -eq 0 ]]; then
      for m in "$*"; do
        echo "this is total $m.log"
        cat $sourcepath/$m.log
      done
      break
    fi
    sleep 1
  done
}

wait_run $docker_all_in_one $docker_build $docker_runtime

docker ps|grep $dev_container_name &> /dev/null
if [[ $? -ne 0 ]]; then
    tag=`cat image/tag`
    x=`docker images $tag|wc -l`
    if [[ $x -eq 1 ]]; then
        cd $sourcepath

        nohup bash ./pre.sh -t compile -m iengine &> $sourcepath/iengine.log &
        nohup bash ./pre.sh -t compile -m manager &> $sourcepath/manager.log &
        nohup bash ./pre.sh -t compile -m plugin-kit &> $sourcepath/plugin-kit.log &
        nohup bash ./pre.sh -t compile -m connectors &> $sourcepath/connectors.log &
        
        wait_run iengine manager plugin-kit connectors

        wait_run

        bash build/build.sh -p 1 -o image
    fi
    cd $basepath
    docker run -e mode=test -p 13000:3000 -p 27017:27017 -v $sourcepath:/tapdata-source/ -i --name=$dev_container_name `cat image/tag` bash
    if [[ $? -ne 0 ]]; then
        exit 127
    fi
fi
