# frozen_string_literal: true

require 'mkmf-rice'

# --with-taglib-dir - the install dir that a custom build of taglib has been deployed to.
dir = with_config('taglib-dir')
if dir && !dir.empty?
  dir = Pathname.new(dir)
  dir = dir.expand_path if dir.to_s.start_with?('~') # ~/.local
  # treat relative paths as relative to the project root
  dir = Pathname.new(__FILE__).dirname.parent.parent.expand_path / dir if dir.relative?
  raise "TAGLIB_DIR does not exist: #{dir}" unless dir.directory?

  dir_config('tag', dir.to_path)
end

have_library('tag') || abort('TagLib is required')

append_cppflags('-g,-DDEBUG') if enable_config('debug')

# Add to existing flags
append_ldflags('-Wl,--no-undefined')
create_makefile('taglib_simple_fileref')
