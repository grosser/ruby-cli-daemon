#!/usr/bin/env bash

# tail a file but stop without error when file is removed
# so we do not print "Terminated" when killing log streamers (happens on osx CI)
# TODO: does not work
file=${TMPDIR}testing
echo hello > $file
awk 'BEGIN{while(( getline line<"Gemfile") > 0 ) { print line }}'
