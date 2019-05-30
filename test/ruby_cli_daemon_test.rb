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

      sleep 0.1 # wait for socket to open
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
end
