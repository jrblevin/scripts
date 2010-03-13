#!/bin/bash

EMACS=/usr/bin/emacs
EMACSCLIENT=/usr/bin/emacsclient
USERID=`id -u`

if test -e /tmp/emacs$USERID/server
then
    echo "Ready."
else
    echo "Starting server."
    $EMACS --daemon
    while [ ! -e "/tmp/emacs$USERID/server" ] ; do sleep 1 ; done
fi

$EMACSCLIENT -c "$@"
