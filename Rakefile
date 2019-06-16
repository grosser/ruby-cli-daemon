# frozen_string_literal: true
require "bundler/setup"
require "bundler/gem_tasks"
require "bump/tasks"

require "yaml"
travis = YAML.load_file(Bundler.root.join('.travis.yml'))
  .fetch('env')
  .map { |v| v.delete('TASK=') }

task default: travis

require "rake/testtask"
Rake::TestTask.new :test do |t|
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
end

desc "Run rubocop"
task :rubocop do
  sh "rubocop --parallel"
end

desc "Debug killing or other long running things"
task :sleep do
  puts "pid #{Process.pid}"
  30.times do
    puts "sleeping"
    sleep 1
  end
end
