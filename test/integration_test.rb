# frozen_string_literal: true
require_relative "test_helper"
require "shellwords"
require "benchmark"
require "tmpdir"

SingleCov.not_covered!

describe "ruby-cli-daemon.sh" do
  # https://grosser.it/2018/11/23/ruby-capture-stdout-without-stdout/
  def capture_stderr
    old_stderr = STDERR.dup
    Tempfile.open('tee_stderr') do |capture|
      STDERR.reopen(capture)
      yield
      capture.rewind
      capture.read
    end
  ensure
    STDERR.reopen(old_stderr)
  end

  def cli(*argv, fail: false, capture: true, &block)
    command = ["#{Bundler.root}/bin/ruby-sli-daemon.sh", *argv].shelljoin
    output = IO.popen("#{command} #{"2>&1" if capture}", &(block || :read))
    raise "#{fail ? "UNEXPECTED SUCCESS" : "FAILURE"}\n#{command}\n#{output}" if $?.success? == fail
    output
  end

  describe "options" do
    it "can show version" do
      cli("-v").must_equal "#{RubyCliDaemon::VERSION}\n"
      cli("--version").must_equal "#{RubyCliDaemon::VERSION}\n"
    end

    it "can show help" do
      cli("-h").must_include "Show this"
      cli("--help").must_include "Show this"
    end

    it "shows help without arguments" do
      cli(fail: true).must_include "Show this"
    end

    it "fails with unknown flags" do
      cli("--foo", fail: true).must_include "Show this"
    end
  end

  describe "stop" do
    it "kills running processes" do
      Benchmark.realtime do
        t = Thread.new { `ruby -e 'sleep(10) && puts(%{ruby_cli_daemon})'` }
        sleep 0.2 # let thread start
        cli("stop")
        t.value
      end.must_be :<, 0.5
    end

    it "fails when no process was found" do
      cli("stop", fail: true).must_equal ""
    end
  end

  describe "run" do
    let(:running) { `pgrep -f ruby_cli_daemon`.count("\n") }

    # execute in our own folder
    around { |t| Dir.mktmpdir { |d| Dir.chdir(d) { t.call } } }

    # do not preload bundler, but when it loads then use local Gemfile that is already bundled
    around do |t|
      Bundler.with_original_env do
        ENV["BUNDLE_GEMFILE"] = "#{Bundler.root}/Gemfile"
        t.call
      end
    end

    # shut everything down after each test
    after { cli("stop") if running > 0 }

    it "is fast when preforked" do
      slow = Benchmark.realtime { cli("rake", "--version") }
      Benchmark.realtime { cli("rake", "--version") }.must_be :<, slow / 2
    end

    it "does not leave streamers behind" do
      cli("rake", "--version")
      running.must_equal 1
    end

    it "can fail" do
      output = cli("rake", "--ohnooo", fail: true)
      output.must_include "invalid option: --ohnoo"
      running.must_equal 1
    end

    it "uses stderr" do
      capture_stderr do
        output = cli("rake", "--ohnooo", fail: true, capture: false)
        output.must_equal ""
      end.must_include "invalid option: --ohnooo\n"
    end

    it "fails when worker crashes" do
      out = cli "wtf", fail: true
      out.must_include "No gem with executable wtf found"
    end

    it "streams" do
      File.write("Rakefile", <<-RUBY)
        task(:foo) { puts 'a'; STDOUT.flush; sleep 0.1; puts 'b' }
      RUBY
      reply = []
      cli "rake", "foo" do |io|
        while (line = io.gets)
          reply << [line, Time.now.to_f]
        end
      end
      reply.reject! { |line, _| line.include?("Terminated") }
      reply.size.must_equal 2, reply
      (reply[1][1] - reply[0][1]).must_be :>, 0.1, reply
    end

    it "can use gems outside of the bundle" do
      raise unless system("ruby -rpru -e 1 &>/dev/null || gem install pru --no-doc >/dev/null")
      cli("pru", "--version")
    end
  end
end
