# frozen_string_literal: true

require_relative 'taglib_simple/version'
require_relative 'taglib_ruby_fileref'
require_relative 'taglib_simple/media_file'

module TagLib
  # Sugar... if you want the class to match the library
  Simple = MediaFile

  LIBRARY_VERSION = [MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION].join('.').freeze
end
