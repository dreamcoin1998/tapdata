#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
sourcepath=$(cd `dirname $0`/../; pwd)
. $basepath/log.sh
. $basepath/env.sh

cd $sourcepath

module=""
type="image"

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

create_tag() {
  echo "create $module run tag $module.run"
  touch $sourcepath/$module.run
}

delete_tag() {
  echo "delete $module run tag $module.run"
  rm $sourcepath/$module.run
}

run_compile() {
  cd $basepath
  echo "run module compile, module is $module"
  chmod u+x build.sh
  bash build.sh -c $module
}

run_docker_pull() {
  cd $basepath
  echo "run docker pull $module"
  chmod u+x build.sh
  docker images | grep $module
  if [[ $? -ne 0 ]]; then
    echo "docker image $module not found, pulling soon"
    docker pull $docker_registry$module
  else
    echo "docker image $module is exists"
  fi
}

create_tag

if [[ $type == "image" ]]; then
  run_docker_pull
fi

if [[ $type == "compile" ]]; then
  run_compile
fi

delete_tag
