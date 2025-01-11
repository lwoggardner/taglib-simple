#!/usr/bin/env ruby
# frozen_string_literal: true

# Generated by Amazon Q

require 'json'
require 'yaml'
require 'taglib_simple'
require 'optparse'
require 'pathname'
require 'base64'

def encode_complex_property(prop)
  return prop.map { |item| encode_complex_property(item) } if prop.is_a?(Array)
  return prop.transform_values { |value| encode_complex_property(value) } if prop.is_a?(Hash)
  return Base64.strict_encode64(prop) if prop.is_a?(String) && prop.encoding == Encoding::ASCII_8BIT

  prop
end

def process_file(file_path, retrieve:, path: file_path)
  mf = TagLib::MediaFile.read(file_path, **retrieve)
  output = mf
           .to_h
           # Show as single value unless entry actually has multiple values
           .transform_values { |value| value.is_a?(Array) && value.size == 1 ? value.first : value }
           # Base64 encode complex properties
           .transform_values { |value| value.is_a?(Hash) ? encode_complex_property(value) : value }

  output[:path] = path unless path.is_a?(IO)
  yield output
end

def process_directory(directory, patterns:, retrieve:, &output)
  count = 0
  now = Time.now
  dir_path = Pathname.new(directory).expand_path

  dir_path.glob(patterns) do |file_path|
    count += 1
    # Use relative path as key
    relative_path = Pathname.new(file_path).relative_path_from(dir_path).to_s

    process_file(file_path, path: relative_path, retrieve: retrieve, &output)
  end

  warn "Processed #{count} files in #{Time.now - now}s"
end

def parse_options
  options = {
    patterns: %w[**/*.mp3 **/*.m4a **/*.flac **/*.ogg **/*.wma],
    output: ->(h) { pp(h) }
  }

  retrieve = {}

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] [DIRECTORY|FILE|-]"

    opts.on('--patterns PATTERNS', Array, 'Comma-separated list of glob patterns to treat as audio files') do |patterns|
      options[:patterns] = patterns
    end

    opts.on('-t', '--[no-]tag', 'Include tag information (default: true)') do |v|
      retrieve[:tag] = v
    end

    opts.on('-p', '--[no-]properties', 'Include properties (default: true)') do |v|
      retrieve[:properties] = v
    end

    opts.on('-a', '--audio-properties [ACCURACY]', %i[fast average accurate],
            'Include audio properties (fast, average, accurate; default: none)') do |v|
      retrieve[:audio_properties] = v || :average
    end

    opts.on('-c', '--complex [PROPERTIES]', Array, 'Comma-separated list of complex properties to retrieve') do |props|
      retrieve[:complex_property_keys] = (props || []).empty? ? :all : props
    end

    opts.on('--[no-]all', 'Include all properties (equivalent to -t -p -a -c)') do |v|
      retrieve[:all] = v
      %i[tag properties].each { |r| retrieve[r] = false if retrieve[r].nil? } unless v
    end

    opts.on('-f', '--format FORMAT', %i[json pretty yaml pp],
            'Output format (json, pretty, yaml, pp; default: pp)') do |format|
      options[:output] =
        case format
        when :pretty
          ->(h) { puts JSON.pretty_generate(h) }
        when :json
          ->(h) { puts JSON.generate(h) }
        when :yaml
          ->(h) { puts YAML.dump(h) }
        else
          ->(h) { pp(h) }
        end
    end

    opts.on('-v', '--version', 'Show version information') do
      puts "taglib-simple gem: #{TagLib::Simple::VERSION}"
      puts "taglib library   : #{TagLib::LIBRARY_VERSION}"
      exit
    end

    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      exit
    end
  end

  parser.parse!

  if ARGV.length > 1
    warn parser
    exit 1
  end

  options[:retrieve] = retrieve
  options[:source] =
    if ARGV.empty?
      if !$stdin.tty? && !$stdin.eof?
        '-'
      else
        warn parser
        exit 1
      end
    else
      ARGV[0]
    end
  options
end

if File.basename(__FILE__) == File.basename($PROGRAM_NAME)
  options = parse_options
  if File.directory?(options[:source])
    process_directory(options[:source], patterns: options[:patterns], retrieve: options[:retrieve], &options[:output])
  elsif options[:source] == '-'
    $stdin.binmode
    process_file($stdin, retrieve: options[:retrieve], &options[:output])
  else
    process_file(options[:source], retrieve: options[:retrieve], &options[:output])
  end
end
