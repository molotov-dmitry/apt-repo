#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT_PATH}"

needupdate=0

for file in incoming/*.deb
do
    test -f "$file"
    
    packageinfo="$(LC_ALL=C dpkg -I "$file" | grep '^ Package: \|^ Source: \|^ Version: \|^ Architecture: ')"
    packagename="$(echo "${packageinfo}" | grep '^ Package: ' | cut -d ' ' -f 3)"
    packagesource="$(echo "${packageinfo}" | grep '^ Source: ' | cut -d ' ' -f 3)"
    packageversion="$(echo "${packageinfo}" | grep '^ Version: ' | cut -d ' ' -f 3)"
    packagearch="$(echo "${packageinfo}" | grep '^ Architecture: ' | cut -d ' ' -f 3)"
    
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
    
    dstname="pool/${letter}/${packagesource}/${packagename}_${packageversion}_${packagearch}.deb"
    
    mv "${file}" "${dstname}"
    
    oldfiles="$(ls "pool/${letter}/${packagesource}/${packagename}_"*"_${packagearch}.deb" | grep -v "${dstname}" || true)"
    
    if [[ -n "$oldfiles" ]]
    then
        rm -fi $oldfiles
    fi 

    needupdate=1
done

if [[ $needupdate -gt 0 ]]
then
    bash update.sh
fi
