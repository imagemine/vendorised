#!/usr/bin/env bash

set -eo pipefail

for item in $(cat workload.txt|grep ready|grep -v "^#");
do
  read source target <<< $(echo $item|awk -F"," '{print $1" "$2}')
  docker pull ${source}
  echo "tagging ${source} as ${target}"
  docker tag ${source} ${target}
  echo "pushing ${target}"
  docker push ${target}
done;


