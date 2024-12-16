# frozen_string_literal: true

if ENV['DEBUGCPP'] == 'Y'
  puts "Paused for GDB #{Process.pid}"
  STDOUT.flush
  STDIN.gets
end

require 'minitest/autorun'
require 'minitest/reporters'

require_relative '../lib/taglib_simple'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new unless ENV.include?('RM_INFO')

require 'tempfile'

def fixture_path(filename)
  File.join(File.dirname(__FILE__), "fixture", filename)
end

def with_filecopy(filename)
  Tempfile.create(anonymous: true, mode: File::RDWR ) do |tf|
    tf.binmode
    tf.write(File.read(filename))
    tf.rewind
    yield tf
  end
end

def since_taglib2(feature = 'Complex Properties')
  if block_given?
    yield if TagLib::MAJOR_VERSION >= 2
  elsif TagLib::MAJOR_VERSION < 2
    skip "#{feature} not available in Taglib #{TagLib::MAJOR_VERSION} (needs 2+)"
  end
end