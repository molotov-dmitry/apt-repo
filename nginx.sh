#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"
HTTP_PORT="$1"
REPO_NAME="$2"

if [[ $HTTP_PORT -le 0 ]]
then
    echo "Incorrect http port: ${HTTP_PORT}"
    false
fi

if [[ -z "${REPO_NAME}" ]]
then
    echo "Incorrect repo name: ${REPO_NAME}"
    false
fi

sudo mkdir -p /etc/nginx/sites-available

cat | sudo tee /etc/nginx/sites-available/repo.conf << _EOF
server
{
    listen ${HTTP_PORT};
    server_name repo ${REPO_NAME};

    location ~ /(.*)/conf
    {
        deny all;
    }

    root ${ROOT_PATH};
}
_EOF

sudo ln -s /etc/nginx/sites-available/repo.conf /etc/nginx/sites-enabled/

sudo service nginx restart
