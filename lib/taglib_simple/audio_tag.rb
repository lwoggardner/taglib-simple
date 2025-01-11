# frozen_string_literal: true

module TagLib
  AudioTag = Data.define :title, :artist, :album, :genre, :year, :track, :comment

  # Represents a normalised subset of tags
  # @see https://taglib.org/api/classTagLib_1_1Tag.html
  class AudioTag < Data
    # @!attribute [r] title
    # @return [String] The title of the track

    # @!attribute [r] artist
    #  @return [String] The artist name

    # @!attribute [r] album
    #   @return [String] The album name

    # @!attribute [r] genre
    #   @return [String] The genre of the track

    # @!attribute [r] year
    #   @return [Integer] The release year

    # @!attribute [r] track
    #   @return [Integer] The track number

    # @!attribute [r] comment
    #   @return [String] Additional comments about the track

    class << self
      # @param [String|:to_path|IO] filename
      # @return [AudioTag]
      def read(filename)
        MediaFile.open(filename, all: false, tag: true, &:tag)
      end

      # @!visibility private
      def check_value(member, value)
        return value if value.nil?

        return check_int_value(member, value) if %i[year track].include?(member)

        check_string_value(member, value)
      end

      # @!visibility private
      def check_int_value(member, value)
        raise TypeError, "#{member} must be a +ve integer" unless value.is_a?(Integer) && value >= 0

        value.zero? ? nil : value
      end

      # @!visibility private
      def check_string_value(member, value)
        raise TypeError, "#{member} must be a string" unless value.is_a?(String)

        value.empty? ? nil : value
      end
    end

    # @return [Hash<Symbol, <String,Integer>>] the tag values as a hash, excluding entries with nil values
    def to_h
      # do not expose nil entries
      super.compact
    end
  end
end
