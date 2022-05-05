#!/bin/bash

set -e

readonly TITLE_LENGTH=50
readonly SPACE_CHAR='.'

readonly CL_RED='\e[31m'
readonly CL_YELLOW='\e[33m'
readonly CL_GREEN='\e[32m'
readonly CL_BLUE='\e[34m'

function spaces()
{
    local string="$1"
    local len=${#string}
    local dot_count=$((${TITLE_LENGTH} - len))
    for dot_i in $(seq 1 ${dot_count})
    do
        echo -n ${SPACE_CHAR}
    done

    return 0
}

function title()
{
    local title="$1"
    echo -n "$title"
    spaces "$title"

    return 0
}

function message()
{
    local msg="$1"
    local color="$2"

    echo -en "$color"
    echo -n "$msg"
    tput sgr0
    echo

    return 0
}

function urldecode()
{
    if [[ -p /dev/stdin ]]; then
        local url_encoded="$(cat -)"
    else
        local url_encoded="$@"
    fi

    printf '%b' "${url_encoded//%/\\x}"
}

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

while read -r line;
do
    if [[ -z "$line" || "$line" == '#'* ]]
    then
        continue
    fi

    mirror="$(echo "$line"  | cut -d ';' -f 1 -s)"
    distrib="$(echo "$line" | cut -d ';' -f 2 -s)"
    section="$(echo "$line" | cut -d ';' -f 3 -s)"
    arch="$(echo "$line"    | cut -d ';' -f 4 -s)"
    source="$(echo "$line"  | cut -d ';' -f 5 -s | cut -d '/' -f 1 -s)"
    package="$(echo "$line" | cut -d ';' -f 5 -s | cut -d '/' -f 2)"

    if [[ -z "$package" ]]
    then
        continue
    fi

    packages+=( "$package" )
    mirrors["$package"]="$mirror"
    sources["$package"]="$source"
    distribs["$package"]="$distrib"
    archs["$package"]="$arch"
    sections["$package"]="$section"

done < packages.list

### Download external packages =================================================

count=${#packages[@]}

for (( i = 0; i < count; i++ ))
do
    package="${packages[$i]}"

    mirror="${mirrors[$package]:=$DEFAULT_MIRROR}"
    source="${sources[$package]:=$package}"
    distrib="${distribs[$package]:=$DEFAULT_DISTRIB}"
    archlist="${archs[$package]:=$DEFAULT_ARCH}"
    section="${sections[$package]:=$DEFAULT_SECTION}"

    if [[ "${source:0:3}" == 'lib' ]]
    then
        letter=${source:0:4}
    else
        letter=${source:0:1}
    fi

    for arch in $archlist
    do
        title "Cheking ${package} ${arch}"

        if [[ -d "pool/${letter}/${source}/" ]]
        then
            localversion="$(ls -1 pool/${letter}/${source}/ | grep "^${package}_[^_]*_${arch}.deb" | sort --version-sort | tail -n1 | cut -d '_' -f 2)"
        else
            localversion=""
        fi

        for retry in {1..5}
        do
            remoteversion="$(curl -s https://${mirror}/${distrib}/pool/${section}/${letter}/${source}/ | grep -o 'a href="[^"]*"' | cut -d '"' -f 2 | urldecode | grep -Ev '^..[/]?$' | grep "^${package}_[^_]*_${arch}.deb" | sort --version-sort | tail -n1 | cut -d '_' -f 2)"

            if [[ -n "$remoteversion" ]]
            then
                break
            fi

            sleep 1
        done

        if [[ -z "$remoteversion" ]]
        then
            message "not found" "${CL_RED}"
            continue
        fi

        if [[ "$remoteversion" == "$localversion" ]]
        then
            message "actual" "${CL_GREEN}"
            continue
        fi

        if [[ "$(echo -e "$localversion\n$remoteversion" | sort --version-sort | tail -n1)" == "$remoteversion" ]]
        then
            message "outdated" "${CL_YELLOW}"
            title "Updating $localversion -> $remoteversion"

            mkdir -p "pool/${letter}/${source}"

            name="${package}_${remoteversion}_${arch}.deb"
            wget -qq "https://${mirror}/${distrib}/pool/${section}/${letter}/${source}/${name}" -O package.tmp && mv -f package.tmp "pool/${letter}/${source}/${name}"

            message "updated" "${CL_BLUE}"

            if [[ -n "$localversion" ]]
            then
                rm -fi "pool/${letter}/${source}/${package}_${localversion}_${arch}.deb"
            fi

            needupdate=1
        fi
    done
done

### Update package list ========================================================

if [[ $needupdate -gt 0 ]]
then
    bash update.sh
fi
