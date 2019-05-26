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

time ruby-cli-daemon rubocop -v # 1.20s
time ruby-cli-daemon rubocop -v # 0.08s
```

TODO
====
 - restart when Gemfile.lock changes
 - support executables that are not named after their libraries
 - better error output when worker fails to  start
 - `stop` command to kill all workers
 - `--version` in sh support
 - capture nohup pid and check that is running

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/ruby_cli_daemon.svg)](https://travis-ci.org/grosser/ruby_cli_daemon)
