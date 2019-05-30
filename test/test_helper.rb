# frozen_string_literal: true
require "bundler/setup"

require "single_cov"
SingleCov.setup :minitest

# stop minitest from running in every fork
require "minitest"
class << Minitest
  PARENT_PID = Process.pid
  def at_exit
    super { yield if Process.pid == PARENT_PID }
  end
end

require "maxitest/autorun"
require "maxitest/threads"
require "maxitest/timeout"
require "mocha/minitest"

require "ruby_cli_daemon/version"
require "ruby_cli_daemon"

require "tmpdir"
