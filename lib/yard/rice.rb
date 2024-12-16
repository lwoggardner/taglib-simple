# frozen_string_literal: true

# lib/yard-rice.rb
require 'yard'

# @!visibility private

module YARD
  # Custom parser that extracts @!yard blocks from C style comments
  class RiceParser < Parser::Ruby::RubyParser
    attr_reader :contents

    def initialize(source, filename)
      super(extract_ruby_docs(source), filename)
    end

    private

    # rubocop:disable Metrics/AbcSize
    def extract_ruby_docs(source)
      ruby_content = []
      in_parse_block = false

      source.each_line do |line|
        if line =~ %r{/\*\*\s*@!yard\s*(.*?)(\*/)?$}
          # Block comment
          in_parse_block = !::Regexp.last_match(2)
          ruby_content << ::Regexp.last_match(1) if ::Regexp.last_match(1)
        elsif line =~ %r{//\s*@!yard\s*(.*)$}
          # Single line @!yard
          ruby_content << ::Regexp.last_match(1)
        elsif line =~ %r{^\s*\*?\s*(.*?)\s*\*/\s*$}
          # end block comment
          ruby_content << ::Regexp.last_match(1)
          in_parse_block = false
        elsif in_parse_block
          # Strip leading asterisks and spaces if present
          line = line.sub(/^\s*\*?\s*/, '')
          ruby_content << line.chomp
        else
          # Maintain line numbering
          ruby_content << ''
        end
      end

      ruby_content.join("\n") # .tap { |t| puts "RICEPARSER\n\n#{t}\n\n" }
    end
    # rubocop:enable Metrics/AbcSize
  end
end

# Register our parser for .hpp files
YARD::Parser::SourceParser.register_parser_type(:hpp, YARD::RiceParser, %w[hpp h])
YARD::Handlers::Processor.register_handler_namespace(:hpp, YARD::Handlers::Ruby)
