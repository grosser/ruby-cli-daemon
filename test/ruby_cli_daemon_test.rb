# frozen_string_literal: true
require_relative "test_helper"
require "rake/version"
require "ostruct"

SingleCov.covered!

describe RubyCliDaemon do
  def restore_env
    old_argv = ARGV
    old_env = ENV.to_h
    old_stdout = STDOUT.dup
    old_stderr = STDERR.dup
    old_stdin = STDIN.dup

    begin
      yield
    ensure
      ARGV.replace old_argv
      ENV.replace old_env
      STDOUT.reopen old_stdout
      STDERR.reopen old_stderr
      STDIN.reopen old_stdin
    end
  end

  around { |test| Dir.mktmpdir { |d| Dir.chdir(d) { test.call } } }

  it "has a VERSION" do
    RubyCliDaemon::VERSION.must_match /^[\.\da-z]+$/
  end

  describe ".install" do
    it "symlinks" do
      RubyCliDaemon.install "foo"
      assert File.symlink?("foo")
      assert File.executable?("foo")
    end

    it "overrides" do
      File.write("foo", "1")
      RubyCliDaemon.install "foo"
      assert File.symlink?("foo")
    end
  end

  describe ".start" do
    it "waits for input and executes it" do
      UNIXSocket.any_instance.stubs(:read).returns("") # TODO: this works from the cli but not in test :(

      Thread.new { RubyCliDaemon.start("foo", "rake") }

      sleep 0.2 # wait for socket to open

      restore_env do
        capture_stream(:STDOUT) do
          UNIXSocket.open("foo") do |socket|
            socket.send_io STDOUT
            socket.send_io STDERR
            socket.send_io STDIN
            socket.puts "--version"
          end

          sleep 0.2 # wait for command to process

          maxitest_kill_extra_threads
        end.must_equal "rake, version #{Rake::VERSION}\n"
      end
      File.read("foo.status").must_equal "0"
    end

    it "stops when timeout is reached" do
      IO.expects(:select).returns(nil)
      RubyCliDaemon.start("foo", "rake")
      refute File.exist?("foo") # cleaned up
    end

    it "does not crash when socket creation fails" do
      FileUtils.expects(:mkdir_p).raises(ArgumentError)
      assert_raises(ArgumentError) { RubyCliDaemon.start("foo", "rake") }
      refute File.exist?("foo")
    end

    it "supports executables with uncommon names" do
      IO.expects(:select).returns(nil)
      RubyCliDaemon.start("foo", "mtest")
    end

    it "complains when executable was not found" do
      Gem::Specification.expects(:detect).returns(nil) # called in the fork too, but cannot expect that
      e = assert_raises RuntimeError do
        RubyCliDaemon.start("foo", "mtest")
      end
      e.message.must_equal "No gem with executable mtest found"
    end

    it "tries bundler and rubygems" do
      Gem::Specification.expects(:detect).times(2).returns(nil, stub(name: "bundler", bin_file: "bar"))
      RubyCliDaemon.expects(:fork_with_return).yields.returns(nil)
      IO.expects(:select).returns(nil)
      RubyCliDaemon.start("foo", "mtest")
    end
  end

  describe "#replace_env" do
    it "replaces everything" do
      restore_env do
        connection = OpenStruct.new(accept: OpenStruct.new(gets: "foo", read: "bar"))
        connection.accept.stubs(:recv_io).returns STDOUT, STDERR, STDIN
        RubyCliDaemon.send(:replace_env, connection)
      end
    end
  end

  describe ".fork_with_return" do
    it "returns" do
      RubyCliDaemon.send(:fork_with_return) { 1 }.must_equal 1
    end

    it "forks" do
      RubyCliDaemon.send(:fork_with_return) { ENV["FOO"] = '1' }
      ENV["FOO"].must_be_nil
    end

    it "re-raises on error" do
      assert_raises ArgumentError do
        RubyCliDaemon.send(:fork_with_return) { raise ArgumentError }
      end
    end

    it "executes inside" do
      RubyCliDaemon.expects(:fork).yields
      assert_raises Errno::EPIPE do
        RubyCliDaemon.send(:fork_with_return) { 1 }
      end
    end
  end
end
