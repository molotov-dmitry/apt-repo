#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT_PATH}"

#### Functions =================================================================

join_by()
{
    local separator="$1"
    shift
    local result="$( printf "${separator}%s" "$@" )"
    echo "${result:${#separator}}"
}

#### Constants =================================================================

readonly distrib='AHome'
readonly openkey='8AE7E3FF56C1A0E32104A1F80B3E9FE030CC35BF'
readonly codenames=('ahome')
readonly components=('contrib')
readonly architcures=('i386' 'amd64' 'all')

#### Generate key file =========================================================

gpg --armor --export "${openkey}" > openkey.gpg

test -s openkey.gpg

#### Generate Packages file ====================================================

for codename in "${codenames[@]}"
do
    for component in "${components[@]}"
    do
        for architecture in "${architcures[@]}"
        do
            dirpath="dists/${codename}/${component}/binary-${architecture}"
            mkdir -p "${dirpath}"
            
            dpkg-scanpackages --arch "$architecture" pool > "${dirpath}/Packages.new"
            mv "${dirpath}/Packages.new" "${dirpath}/Packages"
            
            gzip --keep --force -9 "${dirpath}/Packages"
        done
    done
done

#### Generate Release file =====================================================

for codename in "${codenames[@]}"
do
    for component in "${components[@]}"
    do
        for architecture in "${architcures[@]}"
        do
            dirpath="dists/${codename}/${component}/binary-${architecture}"
            
            echo "Archive: ${codename}"             >  "${dirpath}/Release.new"
            echo "Codename: ${codename}"            >> "${dirpath}/Release.new"
            echo "Origin: ${distrib}"               >> "${dirpath}/Release.new"
            echo "Label: ${distrib}"                >> "${dirpath}/Release.new"
            echo "Component: ${component}"          >> "${dirpath}/Release.new"
            echo "Architecture: ${architecture}"    >> "${dirpath}/Release.new"
            echo "SignWith: ${openkey}"             >> "${dirpath}/Release.new"
            
            mv "${dirpath}/Release.new" "${dirpath}/Release"
            
            gpg -abs -o "${dirpath}/Release.gpg-new" "${dirpath}/Release"
            mv "${dirpath}/Release.gpg-new" "${dirpath}/Release.gpg"
            
            gpg --clearsign --digest-algo SHA512 -o "${dirpath}/InRelease.new" "${dirpath}/Release"
            mv "${dirpath}/InRelease.new" "${dirpath}/InRelease"
            
        done
    done
done

#### Generate global Release file ==============================================

for codename in "${codenames[@]}"
do
    dirpath="dists/${codename}"
    
    echo "Origin: ${distrib}"               >  "${dirpath}/Release.new"
    echo "Label: ${distrib}"                >> "${dirpath}/Release.new"
    echo "Suite: ${codename}"               >> "${dirpath}/Release.new"
    echo "Codename: ${codename}"            >> "${dirpath}/Release.new"
    echo "Architectures: ${architcures[@]}" >> "${dirpath}/Release.new"
    echo "Components: ${components[@]}"     >> "${dirpath}/Release.new"
    echo "SignWith: ${openkey}"             >> "${dirpath}/Release.new"
    
    apt-ftparchive release "dists/$codename" >> "${dirpath}/Release.new"
    
    mv "${dirpath}/Release.new" "${dirpath}/Release"
            
    gpg -abs -o "${dirpath}/Release.gpg-new" "${dirpath}/Release"
    mv "${dirpath}/Release.gpg-new" "${dirpath}/Release.gpg"
    
    gpg --clearsign --digest-algo SHA512 -o "${dirpath}/InRelease.new" "${dirpath}/Release"
    mv "${dirpath}/InRelease.new" "${dirpath}/InRelease"
    
done
