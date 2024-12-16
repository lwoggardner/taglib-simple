require 'minitest/autorun'
require 'minitest/spec'
require_relative 'spec_helper'

describe TagLib::MediaFile do

  let(:mock_fileref) do
    fr = Minitest::Mock.new
    def fr.state(**input)
      (@state ||= { valid: true, read_only: true }).merge!(input)
    end
    def fr.valid?; state[:valid]; end
    def fr.read_only?; state[:read_only]; end
    fr
  end

  def expect_close
    mock_fileref.expect(:close, nil) { mock_fileref.state(valid: false); true }
  end

  let(:retrieve) {{}}
  let(:media_file) { TagLib::MediaFile.new(mock_fileref, **retrieve) }

  let(:audio_properties) {
    TagLib::AudioProperties.new(audio_length: 1000, bitrate: 320, sample_rate: 44100, channels: 2)
  }

  let(:comment) { 'comment'}
  let(:year) { 1996 }
  let(:tag) do
    TagLib::AudioTag.new(
      title: 'title', artist: 'artist', album: 'album', comment: comment, genre: 'genre', year: year, track: 1
    )
  end

  let(:properties) {
    {
      'TITLE' => %w[Title], 'PERFORMERS' => %w[Me You],
      'MUSICBRAINZ_ALBUMID' => [ 'MBID1234567890' ]
    }
  }

  let(:complex) {
    {
      'data' => 'data'.b,
      'mimeType' => 'image/jpeg',
      'deep' => [ 1, "2", { "three" => 3 }],
      'width' => 0,
    }
  }

  def assert_dirty_then_clean
    _(media_file.modified?).must_equal true
    yield
    _(media_file.modified?).must_equal false
  end

  def close_media_file
    expect_close
    media_file.close
    _(media_file.closed?).must_equal(true)
  end
  after do
    mock_fileref.verify
  end

  describe '#audio_properties interface' do

    before do
      mock_fileref.expect(:audio_properties, audio_properties)
      retrieve[:audio_properties] = :average
    end

    it 'delegates readers to the AudioProperties returned from FileRef' do
      _(media_file.audio_length).must_equal 1000
      _(media_file.bitrate).must_equal 320
      _(media_file.sample_rate).must_equal 44100
      _(media_file.channels).must_equal 2
    end

    it 'can be read with hash semantics using Symbol keys' do
      _(media_file[:audio_length]).must_equal 1000
      _(media_file[:bitrate]).must_equal 320
      _(media_file[:sample_rate]).must_equal 44100
      _(media_file[:channels]).must_equal 2
    end

    it '#to_h after close only includes audio_properties' do
      close_media_file
      _(media_file.to_h).must_equal(
        {
          audio_length: 1000,
          bitrate: 320,
          sample_rate: 44100,
          channels: 2
        }
      )
    end
  end

  describe '#tag interface' do

    describe "readers" do

      before do
        retrieve[:tag] = true
        mock_fileref.expect(:tag, tag)
      end

      it 'can be read with hash semantics using Symbol keys' do
        _(media_file[:title]).must_equal 'title'
        _(media_file[:artist]).must_equal 'artist'
        _(media_file[:album]).must_equal 'album'
        _(media_file[:comment]).must_equal 'comment'
        _(media_file[:genre]).must_equal 'genre'
        _(media_file[:year]).must_equal 1996
        _(media_file[:track]).must_equal 1
      end

      it 'delegates readers to the AudioTag returned from FileRef' do
        _(media_file.title).must_equal 'title'
        _(media_file.artist).must_equal 'artist'
        _(media_file.album).must_equal 'album'
        _(media_file.comment).must_equal 'comment'
        _(media_file.genre).must_equal 'genre'
        _(media_file.year).must_equal 1996
        _(media_file.track).must_equal 1
      end

      it '#to_h after close only includes only tag properties' do
        close_media_file
        _(media_file.tag).must_equal(tag)
        _(media_file.to_h.sort).must_equal(
          {
            title: 'title',
            artist: 'artist',
            album: 'album',
            comment: 'comment',
            genre: 'genre',
            year: 1996,
            track: 1
          }.sort
        )
      end

      describe 'with nil valued properties' do
        let(:comment) { nil }
        let(:year) { nil }

        before do
          retrieve[:tag] = true
        end

        it 'excludes nil values from #to_h' do
          close_media_file
          _(media_file.tag).must_equal(tag)
          _(media_file.to_h).must_equal(
            {
              title: 'title',
              artist: 'artist',
              album: 'album',
              genre: 'genre',
              track: 1
            }
          )
        end

        it 'fetches defaults for nil values' do
          _(media_file.fetch(:comment, 'default comment')).must_equal 'default comment'
          _(media_file.fetch(:year, 2999)).must_equal 2999
        end

        it 'raises KeyError for fetch without default' do
          _ { media_file.fetch(:comment) }.must_raise KeyError
          _ { media_file.fetch(:year) }.must_raise KeyError
        end
      end
    end

    describe 'writing' do
      before do
        mock_fileref.state(read_only: false)
      end

      it 'has writers that store pending changes with Symbol keys' do

        new_props = {
          title: 'new title',
          artist: 'new artist',
          album: 'new album',
          comment: nil,
          genre: 'new genre',
          year: 2000,
          track: 3
        }
        media_file.title = 'new title'
        media_file.artist = 'new artist'
        media_file.album = 'new album'
        media_file.comment = nil
        _(media_file.fetch(:comment)).must_be_nil
        media_file.genre = 'new genre'
        media_file.year = 2000
        media_file.track = 3
        _(media_file.track).must_equal 3
        _(media_file[:track]).must_equal(3)

        _(media_file.modifications).must_equal(new_props)

        mock_fileref.expect(:merge_tag_properties, nil, [new_props] )
        mock_fileref.expect(:save, nil)
        assert_dirty_then_clean { media_file.save! }
      end

      it 'raises TypeError for invalid types sent to writers' do
        _ { media_file.title = 123 }.must_raise TypeError
        _ { media_file.year = "2032" }.must_raise TypeError
      end
    end
  end

  describe '#properties interface' do

    describe 'readers' do

      before do
        mock_fileref.expect(:properties, properties )
        # properties - but no complex properties
        retrieve.merge!({properties: true, complex_property_keys: []})
      end

      it 'can be read with hash like semantics' do
        _(media_file['TITLE']).must_equal 'Title'
        _(media_file['PERFORMERS', all: true]).must_equal %w[Me You]
        close_media_file
        _(media_file.title).must_equal('Title', 'uses property if tag not available after close')
      end

      it 'reads unknown properties with #fetch semantics' do
        _ { media_file.fetch('UNKNOWN_PROPERTY') }.must_raise KeyError
        _(media_file.fetch('UNKNOWN_PROPERTY', 'default')).must_equal('default')
        _(media_file.fetch('UNKNOWN_PROPERTY') { |k| _(k).must_equal('UNKNOWN_PROPERTY') && :yes }).must_equal(:yes)
      end

      it 'can be read with dynamic methods' do
        # _(media_file.title).must_equal %w[Title] # :title is part of the #tag interface
        _(media_file.performers).must_equal 'Me'
        _(media_file.musicbrainz__album_id).must_equal 'MBID1234567890', 'double underscore required'
      end

      it 'includes properties in #to_h' do
        close_media_file
        _(media_file.to_h).must_equal(properties)
      end
    end

    describe 'writers' do
      before do
        mock_fileref.state(read_only: false)
      end

      it 'can be written with hash like semantics' do
        new_props = {
          'TITLE' => %w[Title], 'PERFORMERS' => %w[Me You],
          'MUSICBRAINZ_ALBUMID' => [ 'MBID1234567890' ]
        }
        media_file['TITLE'] = 'Title'
        media_file['PERFORMERS'] = %w[Me You]
        media_file['MUSICBRAINZ_ALBUMID'] = [ 'MBID1234567890' ]
        _(media_file.modifications).must_equal(new_props)

        mock_fileref.expect(:merge_properties, nil, [new_props, false])
        mock_fileref.expect(:save, nil)
        assert_dirty_then_clean { media_file.save! }
      end

      it 'can be written with dynamic methods that do not overlap #tag interface' do
        new_props = {
          'PERFORMERS' => %w[Me You],
          'MUSICBRAINZ_ALBUMID' => [ 'MBID1234567890' ],
          'LYRICS' => ['la la la']
        }

        #media_file.title = %w[Title]
        media_file.performers = 'Me', 'You' # multiple values
        media_file.musicbrainz__album_id = ['MBID1234567890'] # underscores
        media_file.lyrics = 'la la la' # single value
        _(media_file.modifications).must_equal(new_props)
        _(media_file.lyrics).must_equal('la la la')
        _(media_file['PERFORMERS', all: true]).must_equal %w[Me You]
        _(media_file.fetch('MUSICBRAINZ_ALBUMID')).must_equal 'MBID1234567890'

        mock_fileref.expect(:merge_properties, nil, [new_props, false])
        mock_fileref.expect(:save, nil)
        assert_dirty_then_clean { media_file.save! }
      end

      it 'raises TypeError for invalid types sent to writers' do
        _ { media_file['TITLE'] = [123] }.must_raise TypeError, 'Array bad type'
        _ { media_file['PERFORMERS'] = [ 'OK', 123 ] }.must_raise TypeError, 'Mixed bad types'
        _ { media_file['MUSICBRAINZ_ALBUMID'] = Object.new }.must_raise TypeError, 'Single value bad type'
      end
    end
  end

  describe 'complex properties' do

    describe 'readers with complex_property_keys=true' do
      before do
        retrieve[:complex_property_keys] = true
        mock_fileref.expect(:complex_property_keys, ['PICTURE'])
        mock_fileref.expect(:complex_property, [complex], ['PICTURE'])
      end

      it 'can be read with hash like semantics' do
        _(media_file['PICTURE']).must_equal(complex)
      end

      it 'can be read with dynamic methods' do
        _(media_file.picture).must_equal(complex)
      end
    end

    describe 'with complex_property_keys = :all' do
      it 'retrieves all complex properties' do
        retrieve[:complex_property_keys] = :all
        mock_fileref.expect(:complex_property_keys, ['PICTURE'])
        mock_fileref.expect(:complex_property, [complex], ['PICTURE'])
        media_file
      end
    end

    describe '#fetch' do
      it 'does not lazily load with empty complex_property_keys' do
        retrieve[:complex_property_keys] = false
        close_media_file
        _ { media_file.fetch('PICTURE') }.must_raise(KeyError)
      end

      it 'does not lazily load complex properties outside of specific complex property_keys' do
        mock_fileref.expect(:complex_property, [complex], ['COMPLEX_OBJECT'])
        retrieve[:complex_property_keys] = %w[COMPLEX_OBJECT]
        close_media_file
        _ { media_file.fetch('PICTURE') }.must_raise(KeyError)
      end

      it 'lazily loads complex properties if requested at #retrieve ' do
        retrieve[:complex_property_keys] = true
        mock_fileref.expect(:complex_property_keys, ['PICTURE'])
        media_file
        mock_fileref.verify # we have not loaded the property yet
        mock_fileref.expect(:complex_property, [complex], ['PICTURE'])
        _(media_file.fetch('PICTURE')).must_equal(complex)
      end
    end

    describe 'writers' do
      let(:new_props) { { 'PICTURE' => [complex]} }
      before do
        mock_fileref.state(read_only: false)
        mock_fileref.expect(:merge_complex_properties, nil, [new_props, false])
        mock_fileref.expect(:save, nil)
      end

      it 'can be written with hash like semantics' do
        media_file['PICTURE'] = [complex]
        _(media_file.modifications).must_equal(new_props)
        _(media_file.picture).must_equal(complex)
        _(media_file['PICTURE']).must_equal(complex)
        _(media_file.fetch_all('PICTURE')).must_equal([complex])
        assert_dirty_then_clean { media_file.save! }
      end

      it 'can be written with dynamic methods' do
        new_props = { 'PICTURE' => [complex] }
        media_file.picture = complex
        _(media_file.modifications).must_equal(new_props)
        assert_dirty_then_clean { media_file.save! }
      end
    end
  end

  describe 'with all types' do
    [
      [ 'force', { all: true } ],
      [ 'lazily', { audio_properties: true } ]
    ]. each do |load_type, init|
        describe "#{load_type} loaded" do
          before do
            retrieve.merge!(init)
            mock_fileref.expect(:audio_properties, audio_properties)
            mock_fileref.expect(:tag, tag)
            mock_fileref.expect(:properties, properties)
            mock_fileref.expect(:complex_property_keys, ['PICTURE'])
          end

          describe '#keys' do
            it 'has all the keys' do
              mock_fileref.expect(:complex_property, [complex], ['PICTURE']) if init[:all]
              _(media_file.keys).must_equal(
                TagLib::AudioProperties.members + TagLib::AudioTag.members + properties.keys + ['PICTURE']
              )
            end
          end

          describe '#to_h via #each' do
            it 'returns hash with all types' do
              mock_fileref.expect(:complex_property, [complex], ['PICTURE'])
              _(media_file.to_h).must_equal(
                audio_properties.to_h.merge(tag.to_h).merge(properties).merge({ 'PICTURE' => [complex] })
              )
            end
          end
        end
    end
  end

  describe 'no types retrieved before close' do
    before do
      close_media_file
    end

    describe "#[]" do
      it 'returns nil for all types' do
        _(media_file['TITLE']).must_be_nil
        _(media_file['PICTURE']).must_be_nil
        _(media_file[:bitrate]).must_be_nil
        _(media_file[:title]).must_be_nil
      end
    end

    describe "#fetch" do
      it 'raises KeyError for all types' do
        _ { media_file.fetch('TITLE') }.must_raise KeyError
        _ { media_file.fetch('PICTURE') }.must_raise KeyError
        _ { media_file.fetch(:bitrate) }.must_raise KeyError
        _ { media_file.fetch(:title) }.must_raise KeyError
      end
    end

    describe "#key?" do
      it 'returns false for all types' do
        _(media_file.key?('TITLE')).must_equal false
        _(media_file.key?('PICTURE')).must_equal false
        _(media_file.key?(:bitrate)).must_equal false
        _(media_file.key?(:title)).must_equal false
      end
    end

    describe "#keys" do
      it 'returns empty array' do
        _(media_file.keys).must_equal([])
      end
    end

    describe "#to_h" do
      it 'returns empty hash via #each' do
        _(media_file.to_h).must_equal({})
      end
    end
  end

  describe '#fetch' do
    it 'raises ArgumentError for invalid key type' do
      _ { media_file.fetch(Object.new) }.must_raise ArgumentError
      _ { media_file.fetch(:unknown_symbol) }.must_raise ArgumentError
    end
  end

  describe '#save!' do

    it 'raises IOError when file is not writable' do
      mock_fileref.state(read_only: true)
      _ { media_file.save! }.must_raise IOError
    end

    it 'saves accumulated changes calling merge methods in the right order' do
      mock_fileref.state(read_only: false)
      order = :start
      obj = Object.new
      media_file.picture = complex
      media_file.title = 'new title'
      media_file.sub_title = 'sub title'
      mock_fileref.expect(:merge_properties, nil) do |_hash, replace_all|
        order = :props if replace_all == obj && order == :start
      end
      mock_fileref.expect(:merge_complex_properties, nil) do |_hash, replace_all|
        order = :complex if replace_all == obj && order == :props
      end
      mock_fileref.expect(:merge_tag_properties, nil) { order = :tag if order == :complex  }
      mock_fileref.expect(:save, nil) { order == :tag }
      assert_dirty_then_clean { media_file.save!(replace_all: obj) }
    end

    it 'resets cached data as though no data was retrieved' do
      mock_fileref.state(read_only: false)
      retrieve.merge!(all: true)
      mock_fileref.expect(:audio_properties, audio_properties)
      mock_fileref.expect(:tag, tag)
      mock_fileref.expect(:properties, properties)
      mock_fileref.expect(:complex_property_keys, ['PICTURE'])
      mock_fileref.expect(:complex_property, [complex], ['PICTURE'])
      mock_fileref.expect(:save, nil)
      media_file.save!
      close_media_file
      _(media_file.audio_properties).must_equal(audio_properties, 'audio props permanently cached')
      _(media_file.tag).must_be_nil
      _(media_file.properties).must_be_nil
      _(media_file.complex_property_keys).must_be_empty
    end
  end

  describe '#clear!' do
    it 'clears cached changes and saves with replace_all= true' do
      mock_fileref.state(read_only: false)
      media_file.picture = complex
      media_file.title = 'new title'
      media_file.sub_title = 'sub title'
      _(media_file.modified?).must_equal true
      mock_fileref.expect(:merge_properties, nil) { |hash, replace_all| hash.empty? && replace_all }
      mock_fileref.expect(:merge_complex_properties, nil) { |hash, replace_all| hash.empty? && replace_all }
      mock_fileref.expect(:save, nil)
      media_file.clear!
    end
  end

  describe "open class method" do

    describe 'without a block' do
      it 'returns a MediaFile' do
        mf = TagLib::MediaFile.open(mock_fileref)
        _(mf).must_be_kind_of TagLib::MediaFile
        _(mf.closed?).must_equal false
      end

      it 'can open a file with retrieve options' do
        mock_fileref.expect(:audio_properties, audio_properties)
        mock_fileref.expect(:tag, tag)
        TagLib::MediaFile.open(mock_fileref, audio_properties: true, tag: true)
      end
    end

    describe 'with a block' do
      it 'yields a MediaFile and returns result of the block' do
        expect_close
        result = TagLib::MediaFile.open(mock_fileref) do |mf|
          'result'
        end
        _(result).must_equal 'result'
      end

      it 'saves automatically and returns the result of the block' do
        mock_fileref.state(read_only: false)
        mock_fileref.expect(:merge_tag_properties, nil, [{title: 'new title'}])
        mock_fileref.expect(:save, nil)
        expect_close
        result = TagLib::MediaFile.open(mock_fileref) do |mf|
          mf.title = 'new title'
          'result'
        end
        _(result).must_equal 'result'
      end

      it 'ensures the file is closed even if an exception is raised' do
        mock_fileref.state(read_only: false)
        expect_close
        warned = false
        _ do
          TagLib::MediaFile.open(mock_fileref) do |mf|
            mf.define_singleton_method(:warn) do |msg|
              warned = msg
            end
            mf.title = 'new title'
            raise 'boom'
          end
        end.must_raise RuntimeError, 'boom'
        _(warned).must_include 'unsaved'
      end
    end
  end

  describe 'read class method' do
    it 'reads only tags and simple properties by default' do
      mock_fileref.expect(:tag, tag)
      mock_fileref.expect(:properties, properties)
      expect_close
      mf = TagLib::MediaFile.read(mock_fileref)
      _(mf).must_be_instance_of(TagLib::MediaFile)
      _(mf.closed?).must_equal true
      _(mf.writable?).must_equal false
    end
    it 'reads everything if all is true' do
      mock_fileref.expect(:audio_properties, audio_properties)
      mock_fileref.expect(:tag, tag)
      mock_fileref.expect(:properties, properties)
      mock_fileref.expect(:complex_property_keys, ['PICTURE'])
      mock_fileref.expect(:complex_property, [complex], ['PICTURE'])
      expect_close
      mf = TagLib::MediaFile.read(mock_fileref, all: true)
      _(mf).must_be_instance_of(TagLib::MediaFile)
      _(mf.picture).must_equal complex
    end
  end

  describe 'with a real FileRef' do
    let(:fixture_mp3) { fixture_path('itunes10.mp3')}
    it 'reads the file' do
      mf = TagLib::MediaFile.read(fixture_mp3, all: true)
      _(mf).must_be_instance_of TagLib::MediaFile
      _(mf.closed?).must_equal true
      _(mf.audio_properties).must_be_instance_of TagLib::AudioProperties
      _(mf.tag).must_be_instance_of TagLib::AudioTag
      _(mf.properties).must_be_instance_of Hash
      since_taglib2 do
        _(mf.complex_property_keys).must_equal ['PICTURE']
        picture = mf.picture
        _(picture).must_be_instance_of Hash
        _(picture['mimeType']).must_equal 'image/png'
      end
    end
    it 'reads and writes with File IO' do
      with_filecopy(fixture_mp3) do |io|
        TagLib::MediaFile.open(io, audio_properties: :fast)  do |mf|
          _(mf.bitrate).must_equal 288
          mf.title = 'new title'
          mf.sub_title = 'sub title'
          since_taglib2 do
            mf.picture = { 'mimeType' => 'image/png', 'data' => 'data'.b }
          end
        end

        io.rewind
        mf = TagLib::MediaFile.read(io, complex_property_keys: :all)
        _(mf.title).must_equal 'new title'
        _(mf.sub_title).must_equal 'sub title'
        since_taglib2 do
          _(mf.picture['mimeType']).must_equal('image/png')
          _(mf.picture['data']).must_equal('data'.b)
        end
      end
    end


    it 'can delete all the tags' do
      with_filecopy(fixture_mp3) do |io|
        TagLib::MediaFile.open(io) do |mf|
          mf.clear!
          _(mf.modified?).must_equal false
          _(mf.title).must_be_nil
          _(mf.properties).must_be_empty
          _(mf.complex_properties).must_be_empty
          # _(mf.complex_property_keys).must_be_empty  FileRef does not clear the this list
        end

        io.rewind

        mf = TagLib::MediaFile.read(io, all: true)
        _(mf.title).must_be_nil
        _(mf.properties).must_be_empty
        _(mf.complex_properties).must_be_empty
        _(mf.complex_property_keys).must_be_empty
      end
    end
    it 'audio_properties are not read by default' do
      mf = TagLib::MediaFile.new(fixture_mp3)
      _(mf.audio_properties).must_be_nil
    end

    it 'can close twice without error' do
      mf = TagLib::MediaFile.new(fixture_mp3)
      mf.close
      _(mf.closed?).must_equal true
      mf.close
      _(mf.closed?).must_equal true
    end
  end
end
