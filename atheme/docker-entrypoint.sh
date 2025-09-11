#!/bin/sh

# Use the data directory for database storage, not the config directory
DATADIR=/usr/local/atheme/data
if ! test -w "$DATADIR/"; then
    echo "ERROR: $DATADIR must be mounted to a directory writable by UID 1001"
    exit 1
fi

DBPATH="$DATADIR/services.db"
if test -f "$DBPATH" && ! test -r "$DBPATH"; then
    echo "ERROR: $DBPATH must be readable by UID 1001"
    exit 1
fi

TMPPATH="$DATADIR/services.db.new"
if test -f "$TMPPATH" && ! test -w "$TMPPATH"; then
    echo "ERROR: $TMPPATH must either not exist or be writable by UID 1001"
    exit 1
fi

rm -f /usr/local/atheme/var/atheme.pid
# Pass -D option to specify the correct data directory
/usr/local/atheme/bin/atheme-services -n -c /usr/local/atheme/etc/atheme.conf -D "$DATADIR" "$@"
