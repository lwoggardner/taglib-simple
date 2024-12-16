# frozen_string_literal: true

require_relative 'spec_helper'


# Here we are testing the wrapped FileRef
describe TagLib::Ruby::FileRef do

  def assert_invalid(ref)
    _(ref.valid?).must_equal false
    _(-> { ref.properties }).must_raise TagLib::Error
    _(-> { ref.audio_properties }).must_raise TagLib::Error
    _(-> { ref.tag }).must_raise TagLib::Error
    ref.close # wont raise
  end

  let(:fixture_m4a) { fixture_path('has-tags.m4a') }
  let(:fixture_mp3) { fixture_path('itunes10.mp3')}
  let(:empty_ogg) { fixture_path('empty.ogg') }

  let(:mp3_properties) do
    {
      "ALBUM" => ["Album"],
      "ALBUMARTIST" => ["Album Artist"],
      "ALBUMARTISTSORT" => ["Sort Album Artist"],
      "ALBUMSORT" => ["Sort Album"],
      "ARTIST" => ["Artist"],
      "ARTISTSORT" => ["Sort Artist"],
      "BPM" => ["180"],
      "COMMENT" => ["Comments"],
      "COMMENT:ITUNPGAP" => ["1"],
      "COMPILATION" => ["1"],
      "COMPOSER" => ["Composer"],
      "COMPOSERSORT" => ["Sort Composer"],
      "DATE" => ["2011"],
      "DISCNUMBER" => ["1/2"],
      "GENRE" => ["Heavy Metal"],
      "LYRICS" => ["Lyrics"],
      "SUBTITLE" => ["Description"],
      "TITLE" => ["iTunes10MP3"],
      "TITLESORT" => ["Sort Name"],
      "TRACKNUMBER" => ["1/10"],
      "WORK" => ["Grouping"]
    }
  end

  describe "#initialize" do

    def assert_valid(ref)
      _(ref.valid?).must_equal true
      _(ref.properties).must_be_instance_of Hash
      _(ref.audio_properties).must_be_instance_of TagLib::AudioProperties
      _(ref.tag).must_be_instance_of TagLib::AudioTag
      ref.close
    end

    it "accepts a filename" do
      _(File.exist?(fixture_m4a)).must_equal true
      ref = TagLib::Ruby::FileRef.new(fixture_m4a, :average)
      assert_valid(ref)
    end

    it "accepts an IO object" do
      File.open fixture_m4a, 'rb' do |io|
        ref = TagLib::Ruby::FileRef.new(io, :average)
        assert_valid(ref)
      end
    end

    [nil, false].each do |style|
      it "accepts #{style.inspect} for audio_read_style" do
        ref = TagLib::Ruby::FileRef.new(fixture_m4a, nil)
        _(ref.valid?).must_equal true
        _(ref.audio_properties).must_be_nil
      end
    end

    it 'raises TypeErrors on bad inputs' do
      _(-> { TagLib::Ruby::FileRef.new(1, :average) }).must_raise TypeError
      _(-> { TagLib::Ruby::FileRef.new(fixture_m4a, 1) }).must_raise TypeError
    end

    it "handles non existent files" do
      fr = TagLib::Ruby::FileRef.new('/does/not/exist', :average)
      assert_invalid(fr)
    end

    it 'accepts Pathname' do
      fr = TagLib::Ruby::FileRef.new(Pathname(fixture_m4a), :average)
      assert_valid(fr)
    end

    it 'handles invalid stream' do
      File.open(fixture_path('empty.file')) do |io|
        fr = TagLib::Ruby::FileRef.new(io, :average)
        assert_invalid(fr)
      end
    end
  end

  describe "#audio_properties" do
    it "returns expected values" do
      ref = TagLib::Ruby::FileRef.new(fixture_m4a, :average)
      ap = ref.audio_properties
      _(ap).wont_be_nil
      _(ap.audio_length).must_equal 3708
      _(ap.bitrate).must_equal 3
      _(ap.channels).must_equal 2
      _(ap.sample_rate).must_equal 44100
    end

    it "raises error when accessing properties after close" do
      ref = TagLib::Ruby::FileRef.new(fixture_m4a, :average)
      ref.close
      _(-> { ref.audio_properties }).must_raise TagLib::Error
    end
  end

  describe "#tag" do
    it "returns expected values" do
      ref = TagLib::Ruby::FileRef.new(fixture_mp3, nil)
      tag = ref.tag
      _(tag).wont_be_nil
      _(tag.title).must_equal 'iTunes10MP3'
      _(tag.artist).must_equal "Artist"
      _(tag.album).must_equal "Album"
      _(tag.comment).must_equal "Comments"
      _(tag.genre).must_equal "Heavy Metal"
      _(tag.year).must_equal 2011
      _(tag.track).must_equal 1
    end
  end

  describe "#merge_tag_properties" do

    it "persists tags" do

      properties = {
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        year: 2024,
        track: 11,
        genre: 'Rock',
        comment: 'Test Comment'
      }

      with_filecopy(empty_ogg) do |tf|
        ref = TagLib::Ruby::FileRef.new(tf, nil)

        ref.merge_tag_properties(properties)
        _(ref.tag&.to_h).must_equal(properties)
        ref.save
        ref.close
        tf.rewind
        ref = TagLib::Ruby::FileRef.new(tf, nil)
        _(ref.tag.to_h).must_equal(properties)
      end
    end


    it "handles multiple save operations"
    it "raises error when saving to read-only file"
  end

  def assert_properties(props)
    _(props).wont_be_nil
    _(props).must_be_instance_of Hash
    _(props.frozen?).must_equal true, 'frozen'
    props.each do |key, values|
      _(key).must_be_instance_of String, 'key is String'
      _(values).must_be_instance_of Array, 'values is Array'
      values.each { |v| _(v).must_be_instance_of String }
    end
  end

  describe "#properties" do
    it "returns expected values" do
      ref = TagLib::Ruby::FileRef.new(fixture_mp3, :average)
      props = ref.properties
      assert_properties(props)
      _(props).must_equal(mp3_properties)
    end
  end

  describe "#merge_properties" do
    it "persists properties" do
      properties = {
        'TITLE' => ['Test Song'],
        'ARTIST' => ['Test Artist'],
        'ALBUM' => ['Test Album'],
        'YEAR' => ['2024'],
        'TRACKNUMBER' => ['11'],
        'GENRE' => ['Rock'],
        'COMMENT' => ['Test Comment'],
        'SUBTITLE' => ['Sub Title'],
      }

      with_filecopy(empty_ogg) do |tf|
        ref = TagLib::Ruby::FileRef.new(tf, nil)

        _(ref.properties.size).must_equal(0)
        set_properties = properties.dup
        set_properties['GENRE'] = 'Rock'
        ref.merge_properties(properties)
        _(ref.properties).must_equal(properties)
        ref.save
        ref.close
        tf.rewind
        ref = TagLib::Ruby::FileRef.new(tf, nil)
        _(ref.properties).must_equal(properties)
      end
    end

    it "replaces all existing properties if requested" do
      properties = {
        'TITLE' => ['Test Song'],
        'ARTIST' => ['Test Artist']
      }

      with_filecopy(fixture_path('itunes10.mp3')) do |tf|
        ref = TagLib::Ruby::FileRef.new(tf, nil)
        _(ref.properties.size).must_be :>=, 5

        ref.merge_properties(properties, true) #replace_all
        _(ref.properties).must_equal(properties)
        ref.save
        ref.close
        tf.rewind
        ref = TagLib::Ruby::FileRef.new(tf, nil)
        _(ref.properties).must_equal(properties)
      end
    end
  end

  describe "#complex_properties" do

    it "returns expected values" do
      since_taglib2
      ref = TagLib::Ruby::FileRef.new(fixture_path('itunes10.mp3'), nil)
      _(ref.complex_property_keys).must_equal ['PICTURE']
      picture = ref.complex_property('PICTURE')
      _(picture).must_be_instance_of Array
      _(picture.size).must_equal(1)
      picture = picture.first
      _(picture).must_be_instance_of Hash
      _(picture['mimeType']).must_equal 'image/png'
      _(picture['pictureType']).must_equal 'Other'
      _(picture['data'].encoding).must_equal Encoding::ASCII_8BIT
      _(picture['data'].length).must_equal 2315
      _(picture['data'][0..4]).must_equal "\x89PNG\r".b, "PNG Header"
    end
  end

  describe "#merge_complex_properties" do
    it "persists complex properties" do
      since_taglib2
      picture  = TagLib::Ruby::FileRef.new(fixture_path('itunes10.mp3'), nil)
                                      .complex_property('PICTURE')

      with_filecopy(empty_ogg) do |tf|

        ref = TagLib::Ruby::FileRef.new(tf, nil)

        _(ref.complex_property_keys).must_equal []
        ref.merge_complex_properties({'PICTURE'=> picture})
        _(ref.complex_property_keys).must_equal ['PICTURE']
        ref.save
        ref.close
        tf.rewind
        ref = TagLib::Ruby::FileRef.new(tf, nil)
        _(ref.complex_property_keys).must_equal ['PICTURE']
        ogg_picture = ref.complex_property('PICTURE')
        _(ogg_picture).must_be_instance_of Array
        _(ogg_picture.size).must_equal(1)
        _(ogg_picture.first['colorDepth']).must_equal(0)
      end
    end

    it 'replaces complex properties if requested' do
      since_taglib2

      with_filecopy(fixture_path('itunes10.mp3')) do |tf|

        ref = TagLib::Ruby::FileRef.new(tf, nil)
        _(ref.complex_property_keys).must_equal ['PICTURE']

        ref.merge_complex_properties({}, true) #replace_all
        # the property keys are read once and appended, but never removed
        #(ref.complex_property_keys).must_equal []
        ref.save
        ref.close
        tf.rewind
        ref = TagLib::Ruby::FileRef.new(tf, nil)
        _(ref.complex_property_keys).must_equal []
        ogg_picture = ref.complex_property('PICTURE')
        _(ogg_picture).must_equal []
      end
    end
  end

  describe "#close" do
    it "raises error when accessing properties after close" do
      ref = TagLib::Ruby::FileRef.new(fixture_m4a, :average)
      _(ref.valid?).must_equal true
      ref.close
      assert_invalid(ref)
    end

    it "does not close the io" do
      File.open(fixture_m4a, 'rb') do |io|
        ref = TagLib::Ruby::FileRef.new(io, :average)
        ref.close
        _(io.closed?).must_equal false
      end
    end
  end
end
