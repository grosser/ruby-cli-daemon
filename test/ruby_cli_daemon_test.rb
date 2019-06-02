# frozen_string_literal: true
require_relative "test_helper"
require "rake/version"

SingleCov.covered!

describe RubyCliDaemon do
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
      Thread.new { RubyCliDaemon.start("foo", "rake") }

      sleep 0.2 # wait for socket to open
      UNIXSocket.new("foo").puts "--version"
      sleep 0.2 # wait for command to process
      maxitest_kill_extra_threads

      File.read("foo.out").must_equal "rake, version #{Rake::VERSION}\n"
      File.read("foo.err").must_equal ""
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

  describe ".capture" do
    it "captures all output" do
      Tempfile.create "file" do |f|
        RubyCliDaemon.send(:capture, :STDOUT, f.path) do
          puts 1
          system "echo 2"
        end
        f.rewind
        f.read.must_equal "1\n2\n"
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
