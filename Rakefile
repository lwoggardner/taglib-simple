# frozen_string_literal: true

require 'bundler/gem_tasks'
Rake::Task['install'].clear
Rake::Task['release'].clear

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require 'rake/extensiontask'
Rake::ExtensionTask.new('taglib_ruby_fileref') do |ext|
  ext.ext_dir = 'ext/taglib_ruby_fileref'
end

require 'yard'
require_relative 'lib/yard/rice'
YARD::Rake::YardocTask.new do |t|
  t.options << '--fail-on-warning'
  t.files = %w[lib/**/*.rb ext/**/*.hpp]
end

require 'rake/testtask'
Rake::TestTask.new(:spec) do |t|
  t.libs << 'lib'
  t.test_files = FileList['spec/**/*_spec.rb']
end

# Define default task to run compile, spec, and rubocop
task default: %i[compile rubocop spec yard]
