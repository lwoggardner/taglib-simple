# frozen_string_literal: true

require_relative 'gem_helper'
require_relative 'lib/taglib_simple/version'
GemHelper.install_tasks(version: TagLib::Simple::VERSION)

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require_relative 'tasks/ext_library'
ExtLibrary.new(:taglib) do |t|
  t.configure_options =
    [
      '-DCMAKE_BUILD_TYPE=Release',
      '-DBUILD_EXAMPLES=OFF',
      '-DBUILD_TESTS=OFF',
      '-DBUILD_TESTING=OFF', # used since 1.13 instead of BUILD_TESTS
      '-DBUILD_BINDINGS=OFF', # 1.11 builds bindings by default
      '-DBUILD_SHARED_LIBS=ON' # 1.11 builds static by default
    ].join(' ')
end

require 'rake/extensiontask'
task compile: [:taglib]

Rake::ExtensionTask.new('taglib_simple_fileref') do |ext|
  ext.ext_dir = 'ext/taglib_simple_fileref'
end

require 'yard'
CLOBBER << 'doc'
YARD::Rake::YardocTask.new do |t|
  t.options << '--fail-on-warning'
end

require 'rake/testtask'
Rake::TestTask.new(:spec) do |t|
  t.libs << 'lib'
  t.test_files = FileList['spec/**/*_spec.rb']
end

# Define default task to run compile, spec, and rubocop
task default: %i[rubocop compile spec yard]
