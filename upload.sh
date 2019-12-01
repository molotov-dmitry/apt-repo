#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT_PATH}"

needupdate=0

### Update local packages ======================================================

echo "Updating local packages..." >&2

for file in incoming/*.deb
do
    test -f "$file" || continue
    
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

### Update remote packages =====================================================

echo "Updating remote packages..." >&2

declare -a packages
declare -A mirrors
declare -A sources
declare -A distribs
declare -A archs
declare -A sections

### Default configurations =====================================================

DEFAULT_MIRROR='mirror.yandex.ru'
DEFAULT_DISTRIB='linuxmint-packages'
DEFAULT_ARCH='all'
DEFAULT_SECTION='main'

### Packages ===================================================================

packages=( 'mint-themes' 'mint-x-icons' 'mint-y-icons' 'rabbitvcs-core' 'rabbitvcs-nautilus' )

count=${#packages[@]}

distribs['rabbitvcs-core']='debian'
distribs['rabbitvcs-nautilus']='debian'

sources['rabbitvcs-core']='rabbitvcs'
sources['rabbitvcs-nautilus']='rabbitvcs'

### Download external packages =================================================

for (( i = 0; i < count; i++ ))
do
    package="${packages[$i]}"

    mirror="${mirrors[$package]:=$DEFAULT_MIRROR}"
    source="${sources[$package]:=$package}"
    distrib="${distribs[$package]:=$DEFAULT_DISTRIB}"
    arch="${archs[$package]:=$DEFAULT_ARCH}"
    section="${sections[$package]:=$DEFAULT_SECTION}"

    letter=${source:0:1}
    localversion="$(ls -1 pool/${letter}/${source}/ | grep "^${package}_[0-9.]*_${arch}.deb" | sort --version-sort | tail -n1 | cut -d '_' -f 2)"
    remoteversion="$(curl -s -l ftp://${mirror}/${distrib}/pool/${section}/${letter}/${source}/ | grep "^${package}_[0-9.]*_${arch}.deb" | sort --version-sort | tail -n1 | cut -d '_' -f 2)"

    if [[ -z "$remoteversion" || "$remoteversion" == "$localversion" ]]
    then
        continue
    fi

    if [[ "$(echo -e "$localversion\n$remoteversion" | sort --version-sort | tail -n1)" == "$remoteversion" ]]
    then
        echo "Updating $package from $localversion to $remoteversion" >&2

        name="${package}_${remoteversion}_${arch}.deb"
        wget -qq "https://${mirror}/${distrib}/pool/${section}/${letter}/${source}/${name}" -O "pool/${letter}/${source}/${name}"

        if [[ -n "$localversion" ]]
        then
            rm -fi "pool/${letter}/${source}/${package}_${localversion}_${arch}.deb"
        fi

        needupdate=1
    fi
done

### Update package list ========================================================

if [[ $needupdate -gt 0 ]]
then
    bash update.sh
fi
