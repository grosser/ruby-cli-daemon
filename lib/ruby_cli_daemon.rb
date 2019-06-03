# frozen_string_literal: true
require "fileutils"
require "socket"
require "shellwords"

module RubyCliDaemon
  TIMEOUT = 60 * 60

  class << self
    def install(path)
      File.unlink(path) if File.exist?(path)
      File.symlink(File.expand_path("../bin/ruby-cli-daemon.sh", __dir__), path)
    end

    def start(socket, executable)
      path = preload_gem(executable)
      server = create_socket(socket) # do this last, it signals we are ready

      loop do
        return unless (command = wait_for_command(server))
        command, env = command
        # execute the command in a fork
        capture :STDOUT, "#{socket}.out" do
          capture :STDERR, "#{socket}.err" do
            _, status = Process.wait2(fork do
              ENV.replace env
              ARGV.replace(command) # uncovered
              load path # uncovered
            end)

            # send back response
            File.write("#{socket}.status", status.exitstatus)
          end
        end
      end
    ensure
      # signal that this program is done so ruby-sli-daemon.sh restarts it
      File.unlink socket if File.exist?(socket)
    end

    private

    # preload the libraries we'll need, to speed up execution
    # first try with bundler and then without
    def preload_gem(executable)
      name, path = fork_with_return do
        require "bundler/setup"
        find_gem_spec(executable)
      end

      if name
        require "bundler/setup"
      else
        name, path = find_gem_spec(executable)
        raise "No gem with executable #{executable} found" unless name
      end

      require name
      GC.start # https://bugs.ruby-lang.org/issues/15878
      path
    end

    def find_gem_spec(executable)
      spec = Gem::Specification.detect { |s| s.executables.include?(executable) }
      [spec.name, spec.bin_file(executable)] if spec # need something we can send out from fork
    end

    def fork_with_return
      read, write = IO.pipe
      Process.wait(fork do
        read.close
        begin
          Marshal.dump(yield, write)
        rescue StandardError => e
          Marshal.dump(e, write)
        end
      end)
      write.close
      result = Marshal.load(read)
      result.is_a?(StandardError) ? raise(result) : result
    end

    def wait_for_command(server)
      return unless IO.select([server], nil, nil, TIMEOUT)
      connection = server.accept
      command = connection.gets.shellsplit
      env = Hash[connection.read.split("--RCD-- ")[1..-1].map { |s| s.split(/ /, 2) }]
      connection.close
      [command, env]
    end

    def create_socket(socket)
      FileUtils.mkdir_p(File.dirname(socket))
      UNIXServer.new(socket)
    end

    # StringIO does not work with rubies `system` call that `sh` uses under the hood, so using Tempfile + reopen
    # https://grosser.it/2018/11/23/ruby-capture-stdout-without-stdout/
    def capture(stream, path)
      const = Object.const_get(stream)
      old_stream = const.dup
      const.flush # not sure if that's necessary
      const.reopen(path)
      yield
    ensure
      const.flush # not sure if that's necessary
      const.reopen(old_stream)
    end
  end
end
