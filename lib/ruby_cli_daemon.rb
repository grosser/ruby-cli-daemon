# frozen_string_literal: true
require "fileutils"
require "socket"
require "shellwords"

module RubyCliDaemon
  TIMEOUT = 60 * 60

  class << self
    def install(path)
      File.unlink(path) if File.exist?(path)
      File.symlink(File.expand_path("../bin/ruby-sli-daemon.sh", __dir__), path)
    end

    def start(socket, executable)
      server = create_socket(socket)
      path = preload_gem(executable)

      loop do
        return unless (command = wait_for_command(server))

        # execute the command in a fork
        capture :STDOUT, "#{socket}.out" do
          capture :STDERR, "#{socket}.err" do
            _, status = Process.wait2(fork do
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

    # preload the libraries we'll need to speed up execution
    def preload_gem(executable)
      spec = Gem.loaded_specs.each_value.detect { |s| s.executables.include?(executable) }
      path = spec.bin_file executable
      require spec.name
      GC.start # https://bugs.ruby-lang.org/issues/15878
      path
    end

    def wait_for_command(server)
      return unless IO.select([server], nil, nil, TIMEOUT)
      connection = server.accept
      command = connection.gets.shellsplit
      connection.close
      command
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
