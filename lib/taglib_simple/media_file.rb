# frozen_string_literal: true

require_relative 'error'
require_relative 'audio_properties'
require_relative 'audio_tag'
require_relative 'types'
require_relative '../taglib_simple_fileref'
require 'forwardable'

module TagLib
  # rubocop:disable Metrics/ClassLength

  # Attribute and Hash like semantics unifying various TagLib concepts into a single interface:
  #
  # | Retrieve Method      | Attribute access     | Hash Key    | Example Key | Value Type          | TagLib Type      |
  # |:---------------------|:---------------------|:------------|:------------|:--------------------|:-----------------|
  # | {audio_properties}   | read only            | Symbol (r)  | :bitrate    | Integer             | AudioProperties  |
  # | {tag}                | read/write           | Symbol (rw) | :title      | String or Integer   | Tag              |
  # | {properties}         | read/write (dynamic) | String (rw) | "COMPOSER"  | Array[String]       | PropertyMap      |
  # | {complex_properties} | read/write (dynamic) | String (rw) | "PICTURE"   | Array[Hash[String]] | List[VariantMap] |
  #
  # TagLib requires {#audio_properties} to be specifically requested at {#initialize} while the other components can be
  # lazily loaded as required.
  #
  # For read-only usage {.read} can be used to {#retrieve} the required components from TagLib,
  # {#close} the file, and continue working with the read-only result.
  #
  # @example general read/write usage (auto saved)
  #   TagLib::MediaFile.open(filename, audio_properties: true) do |media_file|
  #     media_file.sample_rate             # => 44100
  #     media_file.title                   # => 'A Title'
  #     media_file['LANGUAGE']             # => 'English'
  #     media_file.language                # => 'English'
  #     media_file['ARTISTS', all: true]   # => ['Artist 1', 'Artist 2']
  #     media_file.all_artists             # => ['Artist 1', 'Artist 2']
  #     media_file.title = 'A New Title'   # => ['A New Title']
  #   end
  #
  # @example general read only usage
  #   media_file = TagLib::MediaFile.read(filename) # => <MediaFile closed?=true>
  #   media_file.properties                         # => { 'TITLE' => 'Title',...}
  #   media_file.tag                                # => <AudioTag>
  #   media_file.audio_properties                   # => nil
  #   media_file.title                              # => 'Title'
  #   media_file.title = 'A New Title'              # Error! not writable
  # @example read with cover art (explicit complex property)
  #   media_file = TagLib::MediaFile.read(filename, complex_property_keys: ['PICTURE'])
  #   media_file.picture                            # => { 'data' => '<binary data', 'mimeType' => 'image/png'... }
  # @example read everything available to taglib
  #   media_file = TagLib::MediaFile.read(filename, all: true)
  #   media_file.audio_properties                   # => <AudioProperties>
  #   media_file.complex_property_keys              # => ['PICTURE'...]
  # @example only tag
  #   tag = TagLib::AudioTag.read(filename) # => <AudioTag>
  # @example only audio_properties
  #   audio_properties = TagLib::AudioProperties.read(filename) # => <AudioProperties>
  class MediaFile
    class << self
      # Open a file with TagLib
      # @param [String, Pathname, IO] filename The path to the media file
      # @param [Hash] init see {#initialize}
      # @yield [media_file]
      #   When a block is given, opens the file, yields it to the block, saves any changes,
      #   ensures the file is closed, and returns the block's result.
      # @yieldparam [MediaFile] media_file The open file if a block is given
      # @return [MediaFile] If no block is given, returns the open media file
      # @return [Object] otherwise returns the result of the block
      # @raise [Error] If TagLib is unable to process the file
      def open(filename, **init)
        f = new(filename, **init)
        return f unless block_given?

        begin
          yield(f).tap { f.save! if f.modified? }
        ensure
          f.close
        end
      end

      # Read information from TagLib, close the file, returning the MediaFile in a read-only state.
      # @param [String, Pathname, IO] filename
      # @param [Hash<Symbol>] init see {#initialize}.
      #   defaults to retrieving only {#properties} and #{tag}
      # @return [MediaFile] a {#closed?} media file
      # @see AudioTag.read
      # @see AudioProperties.read
      def read(filename, properties: true, tag: true, **init)
        self.open(filename, properties:, tag:, **init, &:itself)
      end
    end

    include Enumerable
    extend Forwardable

    # @param [String, Pathname, IO] file
    #   either the name of a file, an open File or an IO stream
    # @param [Symbol<:fast,:average,:accurate>] audio_properties
    #   if not set no {AudioProperties} will be read otherwise :fast, :average or :accurate
    # @param [Hash] retrieve property types to retrieve on initial load. The default is to pre-fetch nothing.
    #   See {#retrieve}.
    # @raise [Error] if TagLib cannot open or process the file
    def initialize(file, all: false, audio_properties: all && :average, **retrieve)
      @fr = file.respond_to?(:valid?) ? file : Simple::FileRef.new(file, audio_properties)
      raise Error, "TagLib could not open #{file}" unless @fr.valid?

      @audio_properties = (audio_properties && @fr.audio_properties) || nil
      reset
      self.retrieve(all:, **retrieve)
    end

    # Retrieve and cache specific property types rom TagLib
    #
    # Properties will be lazily loaded as long as the file is open so calling this method is generally not required.
    #
    # Typically called from #{initialize} but can be invoked directly, eg to force reload of data after {#save!}.
    #
    # @param [Boolean] all default for other properties
    # @param [Boolean] tag if true forces retrieve of {tag}
    # @param [Boolean] properties if true forces retrieve of {properties}
    # @param [Array<String>|Boolean|Symbol<:lazy,:all>|nil] complex_property_keys
    #   list of properties to specifically treat as _complex_
    #
    #   * given an Array the specifically requested complex properties will be immediately retrieved from TagLib
    #   * explicitly false is equivalent to passing an empty array
    #   * given `true` will immediately fetch the list from TagLib, but not the properties themselves
    #   * given ':all' will retrieve the list from TagLib and then retrieve those properties
    #   * given ':lazy' will explicitly reset the list to be lazily fetched
    #   * otherwise nil does not change the previously setting
    #
    #   While the file is open, a specific complex property can be retrieved using {#complex_properties}[] regardless of
    #   what is set here.
    # @return [self]
    def retrieve(all: false, tag: all, properties: all, complex_property_keys: (all && :all) || nil)
      self.properties if properties
      self.tag if tag

      retrieve_complex_property_keys(complex_property_keys) && fill_complex_properties

      self
    end

    # @return [Boolean] true if the file or IO is closed in TagLib
    # @note Properties retrieved from TagLib before #{close} remain accessible. Reader methods for any missing
    #       property types will return as though those properties are not set. Writer methods will raise {Error}.
    def closed?
      !valid?
    end

    # @return [Boolean] true if the file is open and writable
    def writable?
      !closed? && !read_only?
    end

    # Close this file - releasing memory , file descriptors etc... on the TagLib library side while retaining
    # any previously retrieved data in a read-only state.
    # @return [self]
    def close
      warn "closing with unsaved properties #{@mutated.keys}" if @mutated&.any?
      self
    ensure
      @fr.close
    end

    # @!group Audio Properties (delegated)

    # @!attribute [r] audio_properties
    # @return [AudioProperties]
    # @return [nil] if audio_properties were not retrieved at {#initialize}
    attr_reader :audio_properties

    # @!attribute [r] audio_length
    #  @return [Integer] The length of the audio in milliseconds if available

    # @!attribute [r] bitrate
    #   @return [Integer] The bitrate of the audio in kb/s if available

    # @!attribute [r] sample_rate
    #   @return [Integer] The sample rate in Hz if available

    # @!attribute [r] channels
    #   @return [Integer] The number of audio channels

    def_delegators :audio_properties, *AudioProperties.members

    # @!endgroup

    # @!macro [new] lazy
    #   @note If the file is open this will lazily retrieve all necessary data from TagLib, otherwise only data
    #         retrieved before the file was closed will be available.

    # @!group Tag Attributes (delegated)

    # @!attribute [r] tag
    # @return [AudioTag] normalised tag information.
    # @return [nil] if file was closed without retrieving tag
    # @!macro lazy
    def tag(lazy: !closed?)
      @tag ||= (lazy || nil) && @fr.tag
    end

    # @!attribute [rw] title
    #   @return [String, nil] The title of the track if available

    # @!attribute [rw] artist
    #   @return [String, nil] The artist name if available

    # @!attribute [rw] album
    #   @return [String, nil] The album name if available

    # @!attribute [rw] genre
    #   @return [String, nil] The genre of the track if available

    # @!attribute [rw] year
    #   @return [Integer, nil] The release year if available

    # @!attribute [rw] track
    #   @return [Integer, nil] The track number if available

    # @!attribute [rw] comment
    #   @return [String, nil] Additional comments about the track if available

    AudioTag.members.each do |tag_member|
      define_method tag_member do
        return @mutated[tag_member] if @mutated.key?(tag_member)

        # if the file is closed then try and use #properties if we don't have #tag
        # probably won't work for track and year
        tag_value = tag ? tag.public_send(tag_member) : properties.fetch(tag_member.to_s.upcase, [])&.first
        tag_value && (%i[year track].include?(tag_member) ? tag_value.to_i : tag_value)
      end

      define_method :"#{tag_member}=" do |value|
        write_property(tag_member, AudioTag.check_value(tag_member, value))
      end
    end

    # @!endgroup

    # @!group General Properties

    # @!attribute [r] properties
    # @return [Hash<String, Array<String>>]
    #    the available simple string properties (frozen)
    # @return [nil] if file was closed without retrieving properties.
    # @!macro lazy
    def properties(lazy: !closed?)
      @properties ||= (lazy || nil) && @fr.properties
    end

    # @!attribute [r] complex_properties
    # @return [Hash<String>] a hash that lazily pulls complex properties from TagLib
    attr_reader :complex_properties

    # @!attribute [r] complex_property_keys
    # Set of keys that represent complex properties.
    #
    # Used to determine whether #{complex_properties} or #{properties} is used to find a given key.
    #
    #   * Any keys already retrieved into {#complex_properties} are always included.
    #   * If no keys were provided to {#retrieve} the list of keys will be lazily fetched from TagLib if possible.
    #
    # @return [Array<String>] subset of keys that represent complex properties
    # @!macro lazy
    def complex_property_keys(lazy: !closed?)
      @complex_properties.keys | ((lazy && (@complex_property_keys ||= @fr.complex_property_keys)) || [])
    end

    # @!endgroup

    # @!group Hash Semantics

    # Get a property
    # @param [String, Symbol] key
    # @param [Boolean] all if set property keys will return a list, otherwise just the first value
    # @param [Boolean] saved if set only saved values will be used, ie {#modifications} will be ignored
    # @return [Integer] where *key* is an {AudioProperties} member
    # @return [String, Integer] where *key* is an {AudioTag} member
    # @return [String, Array<String>] for a simple property
    # @return [Hash, Array<Hash>] for a complex property
    # @return [nil] if the *key* is not found
    # @!macro lazy
    def [](key, all: false, saved: false)
      public_send(all ? :fetch_all : :fetch, key, nil, saved:)
    end

    # Fetch the first available value for a property from the media file
    # @param [String, Symbol] key
    # @param [Object] default optional value to return when *key* is not found and no block given
    # @param [Boolean] saved if set only saved values will be used, ie {#modifications} will be ignored
    # @yield [key] optional block to execute when *key* is not found
    # @return [Integer] where *key* is an {AudioProperties} member
    # @return [String, Integer] where *key* is an {AudioTag} member
    # @return [String] for a simple property
    # @return [Hash] for a complex property
    # @return [Object] when *key* is not found and a *default* or block given
    # @raise [KeyError] when *key* is not found and no *default* or block given
    # @!macro lazy
    # @see fetch_all
    def fetch(key, *default, saved: false, &)
      result = fetch_all(key, *default, saved:, &)
      key.is_a?(String) && result.is_a?(Array) ? result.first : result
    end

    # rubocop:disable Metrics/CyclomaticComplexity

    # Fetch a potentially multi-value property from the media file
    # @param [String, Symbol] key
    # @param [Object] default optional value to return when *key* is not found and no block given
    # @param [Boolean] saved if set only saved values will be used, ie {#modifications} will be ignored
    # @yield [key] optional block to execute when *key* is not found
    # @return [Integer] where *key* is an {AudioProperties} member
    # @return [String, Integer] where *key* is an {AudioTag} member
    # @return [Array<String>] for a simple property
    # @return [Array<Hash>] for a complex property
    # @return [Object] when *key* is not found and a *default* or block given
    # @raise [KeyError] when *key* is not found and no *default* or block given
    # @!macro lazy
    def fetch_all(key, *default, saved: false, lazy: !closed?, &)
      return @mutated[key] if !saved && @mutated.include?(key)

      case key
      when String
        fetch_property(key, *default, lazy:, &)
      when *AudioTag.members
        tag(lazy: lazy).to_h.fetch(key, *default, &)
      when *AudioProperties.members
        audio_properties.to_h.fetch(key, *default, &)
      else
        raise ArgumentError, "Invalid key: #{key}"
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Set (replace) a key, these are stored in memory and only sent to taglib on {#save!}
    # @param [String, Symbol] key a property or tag key
    # @param [Array<String|Hash<String>|Integer>] values
    # @return [Array<String>] the values set for simple properties
    # @return [Array<Hash>] the values set for complex properties
    # @return [String|Integer] the value set for {AudioTag} attributes (Symbol key)
    def []=(key, *values)
      case key
      when String
        raise ArgumentError, 'expected 2.. arguments, received 1' if values.empty?

        write_string_property(key, values)
      when *AudioTag.members
        raise ArgumentError, "expected 2 arguments, receive #{values.size} + 1" unless values.size == 1

        write_property(key, AudioTag.check_value(key, values.first))
      else
        raise ArgumentError, "expected String or AudioTag member, received #{key}"
      end
    end

    # Deletes the entry for the given *key* and returns its previously associated value.
    # @param [String, Symbol] key
    # @return [String, Integer, Array<String>, Array<Hash>] the previously associated value for *key*
    # @return [nil] if *key* was not available
    def delete(key, &)
      fetch(key, &).tap { self[key] = nil }
    rescue KeyError
      nil
    end

    # @return [Array<String,Symbol>] the list of available property keys
    # @!macro lazy
    def keys(lazy: !closed?)
      [
        @mutated.keys,
        audio_properties.to_h.keys,
        tag(lazy:).to_h.keys,
        properties(lazy:).to_h.keys,
        complex_property_keys(lazy:)
      ].compact.flatten.uniq
    end

    # rubocop:disable Metrics/AbcSize

    # @param [String|Symbol] key
    #   simple or complex property (String), or a member attribute of {AudioTag} or {AudioProperties} (Symbol)
    # @param [Boolean] saved if set only saved keys are checked, ie {#modifications} are ignored
    # @return [Boolean]
    # @!macro lazy
    def include?(key, saved: false, lazy: !closed?)
      return true if !saved && @mutated.keys.include?(key)

      case key
      when String
        complex_property_keys(lazy:).include?(key) || properties(lazy:).to_h.key?(key)
      when *AudioTag.members
        tag(lazy:).to_h.keys.include?(key)
      when *AudioProperties.members
        !!audio_properties
      else
        false
      end
    end
    # rubocop:enable Metrics/AbcSize

    alias key? include?
    alias member? include?

    # Iterates over each key-value pair in the media file's properties
    #
    # @yield [key, values]
    # @yieldparam [String|Symbol] key
    # @yieldparam [String, Integer, Array<String>, Array<Hash>, nil] value
    # @return [Enumerator] if no block is given
    # @return [self] when a block is given
    # @example Iterating over properties
    #   media_file.each do |key, value|
    #     puts "#{key}: #{value}"
    #   end
    #
    # @example Using Enumerable methods
    #   media_file.to_h
    # @!macro lazy
    def each
      return enum_for(:each) unless block_given?

      keys.each do |k|
        v = fetch_all(k, nil)
        yield k, v if v
      end
      self
    end

    # @!endgroup

    # @!group Dynamic Property Methods

    # @!visibility private
    DYNAMIC_METHOD_MATCHER = /^(?<all>all_)?(?<key>[a-z_]+)(?<setter>=)?$/

    # @!visibility private
    def respond_to_missing?(method, _include_private = false)
      DYNAMIC_METHOD_MATCHER.match?(method) || super
    end

    # Provide read/write accessor like semantics for properties
    #
    # Method names are converted to tag keys and sent to {#[]} (readers) or {#[]=} (writers).
    #
    # Reader methods prefixed with 'all_' will return a list, otherwise the first available value
    #
    # Tag keys are generally uppercase and without underscores between words so these are removed.
    # A double-underscore in a method name will be retained as a single underscore in the tag key.
    #
    # Keys with spaces or other non-method matching characters cannot be accessed dynamically.
    #
    # @return [String, Array<String>, Hash, Array<Hash>, nil]
    # @example
    #   mf.composer                  # -> mf['COMPOSER']
    #   mf.composer = 'New Composer' # -> mf['COMPOSER'] = 'New Composer'
    #   mf.musicbrainz__album_id     # -> mf['MUSICBRAINZ_ALBUMID']
    #   mf.custom__tag__id           # -> mf['CUSTOM_TAG_ID']
    #   mf.artists                   # -> mf['ARTISTS']
    #   mf.all_artists               # -> mf['ARTISTS', all: true]
    # @!macro lazy
    def method_missing(method, *args, &)
      if (match = method.match(DYNAMIC_METHOD_MATCHER))
        key = match[:key].gsub('__', '~').delete('_').upcase.gsub('~', '_')
        if match[:setter]
          public_send(:[]=, key, *args)
        else
          raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" unless args.empty?

          public_send(:[], key, all: match[:all])
        end
      else
        super
      end
    end

    # @!endgroup

    # return [Hash<String|Symbol>] accumulated, unsaved properties (frozen)
    def modifications
      @mutated.dup.freeze
    end

    # @return [Boolean] if any properties been updated and not yet saved.
    # @note Does not check if the values being set are different to their originals, only that something has been set
    def modified?
      @mutated.any?
    end

    # Remove all existing properties from the file.  Any pending modifications will be also lost.
    # @return [self]
    def clear!
      @mutated.clear
      save!(replace_all: true)
      self
    end

    # Save accumulated property changes back to the file.
    # @param [Boolean] replace_all if set the accumulated property changes will replace all previous properties
    # @return [self]
    # @raise [IOError] if the file is not {#writable?}
    # @note all cached data is reset after saving. See {#retrieve}
    def save!(replace_all: false)
      # raise error even if nothing written - you shouldn't be making this call
      raise IOError, 'cannot save, stream not writable' unless writable?

      update(replace_all)
      @fr.save
      reset
      self
    end

    private

    def_delegators :@fr, :valid?, :read_only?

    # try properties first, then complex properties
    def fetch_property(key, *default, lazy: !closed?, &)
      if complex_property_keys(lazy: lazy).include?(key)
        # first try to lazy fetch complex properties because normal hash fetch does not use the default proc
        return (lazy && @complex_properties[key]) || @complex_properties.compact.fetch(key, *default, &)
      end

      (properties(lazy: lazy) || {}).fetch(key, *default, &)
    end

    def write_string_property(key, values)
      values.flatten!(1) # leniently allow an explicit array passed as a value
      values.compact! # explicitly nil resulting in an empty list representing a property to be removed.

      # best efforts fail fast on TypeErrors rather than wait for save
      Types.check_value_types(values) unless values.empty?
      write_property(key, values)
    end

    def write_property(key, values)
      raise Error, 'Read only stream' unless writable?

      @mutated[key] = values
    end

    # for #retrieve
    def retrieve_complex_property_keys(keys)
      @complex_property_keys, fetch =
        case keys
        when false
          []
        when nil
          @complex_property_keys ||= nil
        when Array
          [keys, true]
        when :lazy
          [nil]
        else
          [@fr.complex_property_keys, keys == :all]
        end
      fetch
    end

    def fill_complex_properties
      @complex_property_keys&.each { |k| @complex_properties[k] }
    end

    def update(replace_all)
      group = @mutated.group_by do |k, v|
        if k.is_a?(Symbol)
          :tag
        elsif Types.complex_property?(k, v)
          :complex
        else
          :standard
        end
      end.transform_values(&:to_h)

      %i[standard complex tag].each { |g| send(:"merge_#{g}_properties", group[g], replace_all) }
    end

    def merge_standard_properties(props, replace_all)
      @fr.merge_properties(props || {}, replace_all) if replace_all || props&.any?
    end

    def merge_complex_properties(props, replace_all)
      @fr.merge_complex_properties(props || {}, replace_all) if replace_all || props&.any?
    end

    def merge_tag_properties(props, _ignored)
      @fr.merge_tag_properties(props || {}) if props&.any?
    end

    def reset
      (@mutated ||= {}).clear
      (@complex_properties ||= Hash.new { |h, k| h[k] = @fr.complex_property(k) unless closed? }).clear
      @complex_property_keys = nil
      @tag = nil
      @properties = nil
    end
  end

  # rubocop:enable Metrics/ClassLength
end
