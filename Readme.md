Preforking to make all ruby binaries faster.

Worker:
- starts when needed
- is kept alive per directory and executable
- prefer bundled executables
- stops when not used for 1 hour
- uses callee's environment

Usage
=====

```Bash
# install gem and shell executable
gem install ruby-cli-daemon
ruby -rruby_cli_daemon -e "RubyCliDaemon.install '/usr/local/bin/ruby-cli-daemon'"

alias rubocop="ruby-cli-daemon rubocop --color" # add to ~/.bash_profile
rubocop -v # cold start 1.20s
rubocop -v # warm start 0.08s
```

Traps
=====
 - do not use to `rake release` a gem, since gemspec will not be reloaded
 - worker does not restart when: Gemfile/Gem/monkey-patches change
 - env vars that are read on startup cannot be changed
 - no TTY might some programs skip confirmation prompts or hang

TODO
====
 - support multiline inputs
 - support piping to program
 - support `STDOUT.tty?` when tty
 - restart when Gemfile.lock changes
 - support debian
 - do not print "Terminated" when killing log streamers (happens on osx CI) see experiments/tail.sh

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/ruby-cli-daemon.svg)](https://travis-ci.org/grosser/ruby-cli-daemon)
[![coverage](https://img.shields.io/badge/coverage-100%25-success.svg)](https://github.com/grosser/single_cov)
