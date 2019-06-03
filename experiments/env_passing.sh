#!/usr/bin/env bash
# pass newlines and other special characters along
export FOO="



NEWLINE ??
"
{ echo hello ; awk 'BEGIN{for(v in ENVIRON) printf "--RCD-- %s %s", v, ENVIRON[v] }';} | ruby -e "puts 'GOT'; puts STDIN.read"
