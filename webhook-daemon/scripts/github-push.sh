#!/bin/bash

# Functions
die() { echo "error: $@" 1>&2 ; exit 1; }
confDie() { echo "error: $@ Check the server configuration!" 1>&2 ; exit 2; }
debug() {
  [ "$debug" = "true" ] && echo "debug: $@"
}

# Validate global configuration
[ ! -e "$GITHUB_SECRET_FILE" ] && confDie "GITHUB_SECRET_FILE not exist."

# Validate Github hook
signature=$(echo -n "$1" | openssl sha1 -hmac `cat $GITHUB_SECRET_FILE` | sed -e 's/^.* //')
[ "sha1=$signature" != "$x_hub_signature" ] && die "bad hook signature: expecting $x_hub_signature and got $signature"

# Validate parameters
payload=$1
[ -z "$payload" ] && die "missing request payload"
payload_type=$(echo $payload | jq type -r)
[ $? != 0 ] && die "bad body format: expecting JSON"
[ ! $payload_type = "object" ] && die "bad body format: expecting JSON object but having $payload_type"

debug "received payload: $payload"

lockfile="/tmp/mc-delay-reboot.lock"

if [ -e "$lockfile" ]; then
    echo "lockfile exist! exit."
    exit 1
fi

branch=$(echo "$payload" | jq -r '.ref' | sed 's/refs\/heads\///')
commit=$(echo "$payload" | jq -r '.commits[0].id')
commit_url=$(echo "$payload" | jq -r '.commits[0].url')
commit_message=$(echo "$payload" | jq -r '.commits[0].message')

target_branch="publish"
if [ "$branch" == "$target_branch" ]; then
    nohup /scripts/mc-delay-reboot "$commit" "$commit_url" "$commit_message" >/tmp/mc-delay-reboot.log 2>&1  &
else
    echo "not from $target_branch branch, ignore."
fi

