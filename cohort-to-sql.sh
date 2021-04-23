#!/bin/sh

BASEDIR=$(dirname "$0")
JULIA_COPY_STACKS=yes julia --project="$BASEDIR" "$BASEDIR/cohort-to-sql.jl" "$@"
