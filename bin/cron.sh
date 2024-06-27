#!/usr/bin/env bash

cd $SPOLOT
if [ "$(date -u '+%H')" = "00" ] && [ "$(date -u '+%M')" = "00" ]; then
    git pull --rebase
    cp "$SPOLOT/data/sub.txt" "$SPOLOT/data/share/log/sub$(date -u '+%Y%m%d').txt"
    echo "" > "$SPOLOT/data/sub.txt"
    hash=$(ipfs add -r --nocopy -Q "$SPOLOT/data/share/log")
    ipfspub $hash
fi
if [ "$(date -u '+%M')" = "00" ] || [ "$(date -u '+%M')" = "30" ]; then
ipfspub 'Ok!'
feedupdate
fi
