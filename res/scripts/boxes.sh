#!/bin/bash

echo ""
curl --silent https://app.vagrantup.com/${1}/boxes/${2}/ | jq ".versions[0].version"
echo ""
# curl --silent https://atlas.hashicorp.com/$1/boxes/$2 | jq -M ".versions[0].providers[].name"
curl --silent https://app.vagrantup.com/${1}/boxes/${2}/ | jq -M "if .versions[0] != null then .versions[0].providers[].name else empty end"

echo ""
