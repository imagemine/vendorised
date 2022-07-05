#!/usr/bin/env bash

set -eo pipefail

current_hash=$(git log --pretty=format:'%h' --max-count=1)
current_branch=$(git branch --show-current|sed 's#/#_#')

version=""
compare_to="HEAD~1"

get_tag() {
  if [[ ${current_branch} == "main" ]]; then
    git fetch --tags --force
    current_version_at_head=$(git tag --points-at HEAD)
    if [[ -z ${current_version_at_head} ]] || [[ ! "${current_version_at_head}" =~ ^v+ ]]; then 
      commit_hash=$(git rev-list --tags --topo-order --max-count=1)
      latest_version=""
      if [[ "${commit_hash}" != "" ]]; then
        latest_version=$(git describe --tags "${commit_hash}" 2>/dev/null)
      fi
      if [[ ${latest_version} =~ ^v+ ]]; then 
        compare_to=${latest_version}
        read -r a b c <<< "${latest_version//./ }"
        version="$a.$b.$((c+1))"
      else
        version="v1.0.0"
      fi
      echo "version: ${version}"
    else
      echo nothing to build
    fi
  fi
}

tag_and_push() {
  local image_line=$1

  read -r source target <<< "$(echo "$image_line"|cut -d, -s -f1,2 --output-delimiter=' ')"
  if [[ "${target}" != *":"* ]]; then
    target="${target}:$(cut -d: -f2 <<< "$source")"
  fi
  # docker pull "${source}"
  echo "tagging ${source} as ${target}"
  # docker tag "${source}" "${target}"
  echo "pushing ${target}"
  # docker push "${target}"
}

get_tag

changed_files=$(git diff --name-only HEAD "${compare_to}")
echo "Files changed from HEAD to ${compare_to}:"
echo "${changed_files}"

# Renovated images changed - build changed ones
if grep -q "^renovated_images.txt$" <<< "$changed_files"; then
  git diff -w HEAD "${compare_to}" renovated_images.txt | grep "^+[^+]" | cut -c2- | grep -v "^#" | while IFS= read -r item; do
    tag_and_push "$item"
  done
fi

# workload.txt (manually maintained) changed or some other change (e.g. empty commit) - build ready images from workload.txt
if grep -q "^workload.txt$" <<< "$changed_files" || ! grep -q "^renovated_images.txt$" <<< "$changed_files"; then
  grep "ready" workload.txt | grep -v "^#" | while IFS= read -r item; do
    tag_and_push "$item"
  done
fi

# Tag with the new version
if [[ -n ${version} ]]; then
  now=$(date '+%Y-%m-%dT%H:%M:%S%z')

  # shellcheck source=/dev/null
  source project.properties
  git config --global user.email "${email:?}"
  git config --global user.name "${name:?}"

  git tag -m "{\"author\":\"ci\", \"branch\":\"$current_branch\", \"hash\": \"${current_hash}\", \"version\":\"${version}\",  \"build_date\":\"${now}\"}"  ${version}
  git push --tags
fi
