#!/bin/bash

while read image; do
    echo "Testing ${image}..."
    for commercial_type in C1 VC1; do
        server=$(scw create --commercial-type=$commercial_type "$image")
        if [ "$?" = "0" ]; then
            scw rm $server >/dev/null 2>/dev/null
        else
            printf "%s\r\t\t\t%s: failed\n" "$image" "$commercial_type"
        fi
    done
done < <(http https://api-marketplace.scaleway.com/images | jq -r '.images[].name')
