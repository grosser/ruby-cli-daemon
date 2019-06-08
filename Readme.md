Preforking to make all ruby binaries faster.

Worker:
- starts when needed
- kept alive per directory and executable
- prefers bundled executables
- stops when not used for 1 hour
- receives environment / stdin / stdout / stderr

Usage
=====

```Bash
# install gem and shell executable
gem install ruby-cli-daemon
ruby -rruby_cli_daemon -e "RubyCliDaemon.install '/usr/local/bin/ruby-cli-daemon'"

alias rubocop="ruby-cli-daemon rubocop" # add to ~/.bash_profile
rubocop -v # cold start 1.20s
rubocop -v # warm start 0.19s # NOTE: still ~120ms easy fat to trim for future versions
```

Traps
=====
 - do not use to `rake release` a gem, since gemspec will not be reloaded
 - worker does not restart when: Gemfile/Gem/monkey-patches change
 - env vars that are used on startup cannot be changed

TODO
====
 - restart when Gemfile.lock changes
 - support debian

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/ruby-cli-daemon.svg)](https://travis-ci.org/grosser/ruby-cli-daemon)
[![coverage](https://img.shields.io/badge/coverage-100%25-success.svg)](https://github.com/grosser/single_cov)
