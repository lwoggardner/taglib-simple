# frozen_string_literal: true

require_relative 'lib/taglib_simple/version'

Gem::Specification.new do |s|
  s.name        = 'taglib-simple'
  s.version     = TagLib::SIMPLE_GEM_VERSION
  s.authors     = ['Grant Gardner<grant@lastweekend.com.au>']
  s.licenses    = ['MIT']
  s.summary     = 'Ruby binding to C++ TagLib::FileRef interface'
  s.description = <<~DESC
    Ruby binding to TagLib for reading and writing meta-data (tags) of many audio formats.
    This library wraps the TagLib::FileRef interface from the taglib C++ library using RICE
  DESC

  s.require_paths = ['lib']

  s.requirements = ['taglib (libtag1-dev in Debian/Ubuntu, taglib-devel in Fedora/RHEL)']

  s.required_ruby_version = '>= 3.2'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rake-compiler'
  s.add_development_dependency 'redcarpet'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'yard'
  s.add_dependency 'base64'
  s.add_dependency 'rice'

  s.executables = Dir['bin/*.rb'].map { |f| File.basename(f) }
  s.extensions = Dir['ext/**/extconf.rb']
  s.files = Dir['bin/**/*.rb', 'lib/**/*.rb', 'ext/taglib_*/*.{cpp,hpp,h}', '*.md', 'LICENSE.txt', '.yardopts']
  s.metadata['rubygems_mfa_required'] = 'true'
end
