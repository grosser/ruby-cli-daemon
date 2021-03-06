# frozen_string_literal: true
require_relative "test_helper"
require "shellwords"
require "benchmark"
require "tmpdir"

SingleCov.not_covered!

describe "ruby-cli-daemon.sh" do
  def cli(*argv, status: 0, capture: true, &block)
    command = ["#{Bundler.root}/bin/ruby-cli-daemon.sh", *argv].shelljoin
    output = IO.popen("#{command} #{"2>&1" if capture}", &(block || :read))
    raise "UNEXPECTED STATUS #{$?.exitstatus}\n#{command}\n#{output}" if $?.exitstatus != status
    output&.gsub(/.*Terminated.*\n/, "")
  end

  def with_env(env)
    old = ENV.to_h
    env.each { |k, v| ENV[k.to_s] = v }
    yield
  ensure
    ENV.replace old
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
      cli(status: 1).must_include "Show this"
    end

    it "fails with unknown flags" do
      cli("--foo", status: 1).must_include "Show this"
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
      cli("stop", status: 1).must_equal ""
    end
  end

  describe "run" do
    def assert_running(size)
      current = running
      current.count("\n").must_equal size, current
    end

    def running
      `pgrep -lf ruby_cli_daemon`
    end

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
    after { cli("stop") unless running.empty? }

    it "is fast when preforked" do
      slow = Benchmark.realtime { cli("rake", "--version") }
      Benchmark.realtime { cli("rake", "--version") }.must_be :<, slow / 2
    end

    it "does not leave streamers behind" do
      cli("rake", "--version")
      assert_running 1
    end

    it "can fail" do
      output = cli("rake", "--ohnooo", status: 1)
      output.must_include "invalid option: --ohnoo"
      assert_running 1
    end

    it "uses stderr" do
      capture_stream :STDERR do
        output = cli("rake", "--ohnooo", status: 1, capture: false)
        output.must_equal ""
      end.must_include "invalid option: --ohnooo\n"
    end

    it "fails when worker crashes" do
      out = cli "wtf", status: 1
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

    it "it can run in different folders with the same name" do
      Dir.mkdir "foo"
      Dir.mkdir "foo/bar"
      Dir.mkdir "bar"
      Dir.chdir "foo/bar" do
        cli("rake", "--version")
      end
      Dir.chdir "bar" do
        cli("rake", "--version")
      end
      assert_running 2
    end

    it "can use env vars" do
      File.write("Rakefile", <<-RUBY)
        task(:foo) { puts "X\#{ENV["CUSTOM"]}" }
      RUBY
      cli("rake", "foo").must_equal "X\n"
      with_env CUSTOM: "Y" do
        cli("rake", "foo").must_equal "XY\n"
      end
      with_env CUSTOM: "Y\n|\\Z" do
        cli("rake", "foo").must_equal "XY\n|\\Z\n"
      end
    end

    it "can get Ctrl+C ed" do
      File.write("Rakefile", <<-RUBY)
        task(:foo) { sleep 5 } # more than test timeout
      RUBY
      cli("rake", "--version") # start daemon
      t = Thread.new { cli("rake", "foo", status: 1) } # start sleeper
      sleep 0.5 # let sleeper start
      Process.kill(:TERM, `pgrep -lf "rake"`.split("\n").last.to_i) # kill sleeper
      t.value.must_include "SignalException: SIGTERM"
    end

    it "can get sigkilled" do
      File.write("Rakefile", <<-RUBY)
        task(:foo) { sleep 5 } # more than test timeout
      RUBY
      cli("rake", "--version") # start daemon
      t = Thread.new { cli("rake", "foo", status: 127) } # start sleeper
      sleep 0.5 # let sleeper start
      Process.kill(:KILL, `pgrep -lf "rake"`.split("\n").last.to_i) # kill sleeper
      t.value.must_equal ""
    end
  end
end
