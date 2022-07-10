#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
sourcepath=$(cd `dirname $0`/../; pwd)
. $basepath/log.sh
. $basepath/env.sh

cd $basepath

type="image"
module=""

while getopts 't:m:' opt; do
	case "$opt" in
	't')
		type="$OPTARG"
		;;
    'm')
        module="$OPTARG"
        ;;
	esac
done

pull_image() {
    docker images | grep "$docker_registry$module"
    if [[ $? -ne 1 ]]; then
        docker pull $docker_registry$module
    fi
}

create_file() {
    sudo touch /var/run/$module
}

delete_file() {
    sudo rm /var/run/$module
}

compire() {
    cd ../
    bash build/build.sh -c $module
}

create_file

if [[ $type == "image" ]]; then
    pull_image
fi

if [[ $type == "compire" ]]; then
    compire
fi

delete_file


