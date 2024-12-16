# frozen_string_literal: true

require 'mkmf-rice'

# define TAGLIB_DIR (eg to ~/.local) if you have a locally installed taglib somewhere
if ENV.key?('TAGLIB_DIR')
  raise "TAGLIB_DIR does not exist: #{ENV['TAGLIB_DIR']}" unless File.directory?(ENV['TAGLIB_DIR'])

  dir_config('tag', ENV['TAGLIB_DIR'])
end

have_library('tag') || abort('TagLib is required')

# this to help us debug what kind of file/tag we found - the symbols in the so library are mangled
# but still useful
# append_cppflags('-frtti')
# append_cppflags('-g,-DDEBUG') if enable_config('debug')

# Add to existing flags
append_ldflags('-Wl,--no-undefined')
create_makefile('taglib_ruby_fileref')
