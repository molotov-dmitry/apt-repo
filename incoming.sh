#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT_PATH}"

for file in incoming/*.deb
do
    test -f "$file"
    
    packageinfo="$(LC_ALL=C dpkg -I "$file" | grep '^ Package: \|^ Source: ')"
    packagename="$(echo "${packageinfo}" | grep '^ Package: ' | cut -d ' ' -f 3)"
    packagesource="$(echo "${packageinfo}" | grep '^ Source: ' | cut -d ' ' -f 3)"
    
    test -n "${packagename}"
    
    if [[ -z "${packagesource}" ]]
    then
        packagesource="${packagename}"
    fi
    
    if [[ "${packagesource:0:3}" == 'lib' ]]
    then
        letter="${packagesource:0:4}"
    else
        letter="${packagesource:0:1}"
    fi
    
    mkdir -p "pool/${letter}/${packagesource}"
    
    mv "${file}" "pool/${letter}/${packagesource}/"
done
