# frozen_string_literal: true
#
# is preforking rubocop fast enough ?

require "bundler/setup"
require "benchmark"
require "rubocop"
path = Gem.bin_path('rubocop', 'rubocop')
GC.start # makes exit 0.15s faster https://bugs.ruby-lang.org/issues/15878

puts(Benchmark.realtime do
  _, result = Process.wait2(fork do
    ARGV.replace(["-v"])
    load path
  end)
  puts "RESULT: #{result.success?}"
end)
