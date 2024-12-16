# frozen_string_literal: true

module TagLib
  # @!visibility private
  AudioProperties = Data.define(:audio_length, :bitrate, :sample_rate, :channels) do
    class << self
      def read(filename, audio_properties: true)
        raise ArgumentError, 'audio_properties must be one of :average, :fast, :accurate' unless audio_properties

        Taglib::MediaFile.open(filename, audio_properties:, &:audio_properties)
      end
    end
  end

  # @!parse
  #   # Represents the audio properties of a media file
  #   # @see https://taglib.org/api/classTagLib_1_1AudioProperties.html
  #   class AudioProperties < Data
  #
  #     # @!attribute [r] audio_length
  #     #   @return [Integer] The length of the audio in milliseconds
  #
  #     # @!attribute [r] bitrate
  #     #   @return [Integer] The bitrate of the audio in kb/s
  #
  #     # @!attribute [r] sample_rate
  #     #   @return [Integer] The sample rate in Hz
  #
  #     # @!attribute [r] channels
  #     #   @return [Integer] The number of audio channels
  #
  #    # @!scope class
  #    # @!method read(filename, audio_properties: true)
  #    #  @param [String|:to_path|IO] filename
  #    #  @param [Symbol<:average, :fast, :accurate>] audio_properties read style
  #    #  @return [AudioProperties]
  #   end
end
