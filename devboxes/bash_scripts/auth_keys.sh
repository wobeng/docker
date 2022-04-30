#!/bin/sh
set -e

efshomedir="/efs${3}"
if [ -f "$efshomedir/.ssh/id_ed25519.pub"  ]; then
    /usr/bin/cat "$efshomedir/.ssh/id_ed25519.pub" 
    exit 0
fi

/usr/bin/timeout 5s "/opt/aws/bin/eic_run_authorized_keys" "$@"