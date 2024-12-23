# frozen_string_literal: true

require 'rake/tasklib'

# Creates tasks for download, build, install a cmake, or autoconf library that is the dependency of a ruby extensions
class ExtLibrary < Rake::TaskLib
  include Rake::DSL
  # @!attribute [rw] name
  #   @return [Symbol] the name of the task to creates

  # @!attribute [rw] with_config
  #   @return [String] the with-config name used to point at the install dir (default "#{name}-dir")

  # @!attribute [rw] install_dir
  #  @return [String, Pathname] the prefix target

  # @!attribute [rw] source_dir
  #   @return [String, Pathname] the directory to download source to

  # @!attribute [rw] git
  #   @return [String] a format string with %{name}, %{version} to use with git clone.
  #     Default uses 'name' as a https github repo

  # @!attribute [rw] url
  #   @return [String] a format string url to use with curl to download a tar.gz from containing the source

  # @!attribute [rw] version
  #   @return [String] a version name to use as a branch/tag for git clone.

  # @!attribute [rw] configure_options
  #   @return [String] additional options to pass to configure or cmake after the install prefix

  attr_accessor :name, :with_config, :install_dir, :source_dir, :url, :git, :version, :configure_options

  def initialize(name = nil, **opts)
    super()
    @name = name
    opts.each { |k, v| public_send("#{k}=", v) }
    # tmp/taglib-2.0.1 (inc, bin, lib)
    # source dir /tmp/taglib-2.0.1/src
    # version 2.0.1
    yield self if block_given?
    raise 'Must specify a name' unless @name

    init_install_dir
    init_source

    define
  end

  def init_install_dir
    @install_dir ||= install_dir_from_argv(@with_config || "#{@name}-dir")
    @install_dir = File.expand_path(@install_dir) if @install_dir&.start_with?('~')
    @install_dir = Pathname.new(@install_dir) if @install_dir
  end

  def init_source
    return unless @install_dir&.relative?

    @git ||= 'https://github.com/%<name>s/%<name>s.git'
    @source_dir ||= @install_dir / 'src'
    @version ||= @install_dir.basename.to_s.split('-').last
    nil
  end

  def install_dir_from_argv(with_config)
    return nil unless (dir = ARGV.find { |arg| arg.start_with?("--with-#{with_config}") })

    result = dir.split('=')[1]
    return nil if result&.empty?

    result
  end

  def clone
    sh "git clone --depth=1 --branch=#{version} #{format(git, name:, version:)} '#{source_dir}'"
    sh "git -C '#{source_dir}' submodule update --init"
  end

  def download
    sh %(curl -sL "#{format(url, name:, version:)}" | tar xz -C "#{source_dir}")
  end

  private

  def define
    namespace @name do
      directory install_dir if install_dir

      task :fetch_source do
        next if source_dir.exist?

        if url
          download
        elsif git
          clone
        else
          raise "Must specify either git or url if #{source_dir} is not available"
        end
      end

      task configure: :fetch_source do
        if (source_dir / '.configure').exist?
          unless (source_dir / 'Makefile').exist?
            sh "cd #{source_dir} && .configure #{configure_options} --prefix=#{install_dir.expand_path}"
          end
        elsif (source_dir / 'CMakeLists.txt').exist?
          unless (source_dir / 'CMakeCache.txt').exist?
            sh "cd #{source_dir} && cmake #{configure_options} -DCMAKE_INSTALL_PREFIX=#{install_dir.expand_path} ."
          end
        end
      end

      task make_install: [install_dir, :configure] do
        sh "cd #{source_dir} && make && make install"
      end
    end

    desc "Fetch, Configure, Compile, Install if --with-#{with_config} is set"
    task name =>  install_dir&.relative? ? ["#{name}:make_install"] : [] do
      puts "Using #{name} from #{install_dir || 'system install location'}"
    end
  end
  # @rubocop:enable
end
