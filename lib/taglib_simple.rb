# frozen_string_literal: true

require_relative 'taglib_simple/version'
require_relative 'taglib_simple/media_file'

# Ruby interface over TagLib's simple, abstract APIs for audio file tags
# @see http://taglib.github.io/
module TagLib
  # @!parse
  #
  #    # TagLib library major version number
  #    MAJOR_VERSION = runtime_version().major_version()
  #
  #    # TagLib library minor version number
  #    MINOR_VERSION = runtime_version().minor_version()
  #
  #    # TagLib library patch version number
  #    PATCH_VERSION = runtime_version().patch_version()
  #
  #   # TagLib library version - <major>.<minor>.<patch>
  #   LIBRARY_VERSION = runtime_version().toString()
end
