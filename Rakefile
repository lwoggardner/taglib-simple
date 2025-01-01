# frozen_string_literal: true

require 'bundler/gem_tasks'
Rake::Task['install'].clear

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
task default: %i[rubocop compile spec yard]

puts ARGV
