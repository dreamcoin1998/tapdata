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

wait_do_something() {
    array=$1
    wait_time=$2
    for i in $(seq 1 $wait_time); do

        if [[ ${#array[@]} -eq 0 ]]; then
            break
        fi

        for id in "${!array[@]}";
        do
            element=$array[$id]
            ! test -f /var/run/$element && test -f /var/log/$element.log
            if [[ $? -eq 0 ]]; then
                info "this is $element pull log"
                cat /var/log/$element.log
                unset $array[$id]
            fi
        done
        sleep 1
    done
}

echo "start pull images..."
sudo nohup bash ./pre.sh -m $docker_build -t "image" &> /var/log/$docker_build.log &
sudo nohup bash ./pre.sh -m $docker_runtime -t "image" &> /var/log/$docker_runtime.log &
sudo nohup bash ./pre.sh -m $docker_all_in_one -t "image" &> /var/log/$docker_all_in_one.log &

image_list=( $docker_build $docker_runtime $docker_all_in_one )

wait_do_something $image_list 300

if [[ $force -eq 1 ]]; then
    docker rm -f $dev_container_name
    docker rmi -f `cat image/tag`
fi

docker ps|grep $dev_container_name &> /dev/null
if [[ $? -ne 0 ]]; then
    tag=`cat image/tag`
    x=`docker images $tag|wc -l`
    if [[ $x -eq 1 ]]; then
        sudo nohup bash ./pre.sh -m iengine -t "compire" &> /var/log/iengine.log &
        sudo nohup bash ./pre.sh -m manager -t "compire" &> /var/log/manager.log &
        sudo nohup bash ./pre.sh -m plugin-kit -t "compire" &> /var/log/plugin-kit.log &
        sudo nohup bash ./pre.sh -m connectors -t "compire" &> /var/log/connectors.log &

        module_list=("iengine" "manager" "plugin-kit" "connectors")

        wait_do_something $module_list 300

        cd ../
        bash build/build.sh -p 1 -o image
    fi
    cd $basepath
    docker run -e mode=test -p 13000:3000 -p 27017:27017 -v $sourcepath:/tapdata-source/ -i --name=$dev_container_name `cat image/tag` bash
    if [[ $? -ne 0 ]]; then
        exit 127
    fi
fi
