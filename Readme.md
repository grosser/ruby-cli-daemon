Preforking to make all ruby binaries faster.

- Worker starts when needed
- Worker is kept alive per directory and executable
- Worker stops when not used for 1 hour

Usage
=====

```Bash
# install gem and shell executable
gem install ruby-cli-daemon
ruby -rruby_cli_daemon -e "RubyCliDaemon.install '/usr/local/bin/ruby-cli-daemon'"

alias rubocop="ruby-cli-daemon rubocop" # add to ~/.bash_profile
rubocop -v # cold start 1.20s
rubocop -v # warm start 0.08s
```

TODO
====
 - restart when Gemfile.lock changes
 - support executables that are not named after their libraries

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/ruby_cli_daemon.svg)](https://travis-ci.org/grosser/ruby_cli_daemon)
