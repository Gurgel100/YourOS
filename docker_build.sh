#!/bin/bash

# only set `-it` if there is a tty
if [ -t 0 ] && [ -t 1 ];
then
    TTY_PARAM="-it"
fi

docker run $TTY_PARAM --user $(id -u):$(id -g) -v "$(pwd)":/external ghcr.io/gurgel100/youros-dev:latest $@