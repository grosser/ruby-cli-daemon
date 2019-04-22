Preforking daemon that makes all ruby binaries faster (assumes bundle exec)

When executing a ruby executable like `rubocop`, reuse an existing background fork instead to make it execute instantly.

- Fork is kept alive per directory 
- Fork gets restarted when Gemfile.lock changes
- Fork shuts down when not used for 1 hour

Install
=======

```Bash
time bundle exec rubocop -v # 1.2s

gem install ruby-cli-daemon
ruby-cli-daemon wrap rubocop

time rubocop -v # 0.01s
```

Usage
=====

```Ruby
CODE EXAMPLE
```

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/ruby_cli_daemon.svg)](https://travis-ci.org/grosser/ruby_cli_daemon)
