# taglib-simple

{TagLib::MediaFile} provides an idiomatic Ruby interface over [TagLib]'s simple, abstract APIs for audio file tags.

## Install

```gem install taglib-simple``` 

or include in your Gemfile
```gem 'taglib-simple'```

## Usage - taglib.rb

Ruby script that prints tag information for a file or directory

```bash
$ taglib.rb test.mp3
```
```ruby
{:title=>"Test Title",
 :artist=>"Artist",
 :album=>"Album",
 :genre=>"Heavy Metal",
 :year=>2011,
 :track=>1,
 :comment=>"Comments",
 "ALBUM"=>["Album"],
 "ALBUMARTIST"=>["Album Artist"],
 "ALBUMARTISTSORT"=>["Sort Album Artist"],
 "ALBUMSORT"=>["Sort Album"],
 "ARTIST"=>["Artist"],
 "ARTISTSORT"=>["Sort Artist"],
 "COMMENT"=>["Comments"],
 "COMPILATION"=>["1"],
 "DATE"=>["2011"],
 "DISCNUMBER"=>["1/2"],
 "GENRE"=>["Heavy Metal"],
 "LYRICS"=>["Lyrics"],
 "SUBTITLE"=>["Description"],
 "TITLE"=>["Test Title"],
 "TRACKNUMBER"=>["1/10"],
 :path=>"test.mp3"}
```

## Usage - in ruby code

### General Read/Write

```ruby
require 'taglib_simple'

TagLib::MediaFile.open(filename) do |media_file|
  # TagLib::Tag - specific well known tags
  media_file.tag # => <AudioTag> { title: 'The title', artist: 'An Artist', album: nil, ...}
  
  # Attribute like interface
  media_file.title  # => 'The title'
  media_file.year   # => 2024
  media_file.title = 'New Title' # => 'New Title' (writer)
  
  # Hash interface (Symbol keys)
  media_file[:title] # => 'The title'
  
  # TagLib::PropertyMap - arbitrary tags with normalised structure across formats
  media_file.properties # { 'TITLE'  => ['The title'], 'ARTIST' => ['An Artist']}
  
  # Hash interface (String keys)
  media_file['LANGUAGE']                       # => 'English'
  media_file['MUSICBRAINZ_ALBUMID']            # => 'ID1234567890'
  media_file['TITLE'] = 'A new title'          # => ['A new title']          (writer)
  media_file['ARTISTS'] = 'Artist1', 'Artist2' # => [ 'Artist1', 'Artist2' ] (writer)
  media_file.delete('ARTISTS')                 # => [ 'Artist1', 'Artist2' ] (delete a property, return previous value)
  media_file['ARTISTS', all: true]             # => [ 'Artist1', 'Artist2' ] (multi-value reader)
  media_file.fetch_all('ARTISTS', [])          # => [ 'Artist1', 'Artist2' ] or [] if not property for 'ARTISTS'
  
  # including 'complex' properties like cover art
  media_file['PICTURE']                        # => { 'data' => "<binary data", 'mimeType' => "image/png" }
  
  # Arbitrary method like interface over the properties hash
  media_file.language                       # => 'English'
  media_file.musicbrainz__album_id          # => 'ID1234567890'
  media_file.all_artists                    # => ['Artist1', 'Artist2']
  media_file.artists = 'Artist1', 'Artist2' # => ['Artist1', 'Artist2'] (writer)
end
```
Note that {TagLib::MediaFile#save! #save!} is called automatically if the media_file is 
{TagLib::MediaFile#modified? #modified?} within the block, and {TagLib::MediaFile#close #close} is ensured as
the block exits.


### Read only usage

For read-only operations, {TagLib::MediaFile.read} ensures the file is closed, and memory held
within the underlying TagLib library is released, before the requested information is returned.

**Default retrieves Tag and PropertyMap from Taglib, closes the file and returns the MediaFile in read-only mode**
```ruby
mf = TagLib::MediaFile.read(filename)
mf.tag                   # => <AudioTag> { title: 'title' ...}
mf.title                 # => 'title'
mf.properties            # => { 'TITLE' => 'title', 'LYRICS' => 'la la la'}
mf.lyrics                # => 'la la la'
mf.complex_properties    # => {} (not retrieved from taglib)
mf.audio_properties      # => nil (not retrieved from taglib)
mf.closed?               # => true
mf.writable?             # => false
mf.title = 'New Title'   # Error! not writable.
```

**Read including cover art as a complex property**
```ruby
mf = TagLib::MediaFile.read(filename, complex_property_keys: ['PICTURE'])
mf.title                 # => 'A title'
mf.picture               # => { 'data' => "<binary data", 'mimeType' => "image/png" }
```

**Read everything taglib has about a file**
```ruby
mf = TagLib::MediaFile.read(filename, all: true)
mf.tag                   # => <AudioTag>
mf.properties            # => { 'TITLE' => 'title' ...}
mf.complex_properties    # => { 'PICTURE' => { 'data' => "<binary data", 'mimeType' => "image/png" } ...}
mf.audio_properties      # => <AudioProperties>
mf.sample_rate           # 44100
```

**Read using just the Tag API**
```ruby
tag = TagLib::AudioTag.read(filename) # => <AudioTag>
tag.title                             # => 'A Title'
tag.year                              # => 1983
```

### Advanced: Working with IO Objects

In addition to String based file names {TagLib::MediaFile} also supports general File and IO objects.

**Read tags from standard input**
```ruby
$stdin.binmode
JSON.pretty_generate(TagLib::MediaFile.read($stdin).to_h)
```

## Why? (OR: why not [taglib-ruby])

The existing [taglib-ruby] gem provides a more or less direct wrapping of the full [TagLib] C++ library via [SWIG] but 
[does not yet support the PropertyMap interface](https://github.com/robinst/taglib-ruby/issues/148).

### Benefits:
* Simple, idiomatic ruby interface.
* Uses TagLib's builtin auto-detection capabilities to work with any audio format TagLib supports  
* Supports complex properties - album covers embedded in tags
* Supports Ruby IO objects in addition to plain files
* Simplified memory management - no native [TagLib] objects are exposed to Ruby

### Limitations:

No access to [TagLib]'s "format specific APIs for advanced API users", ie no understanding of the underlying type
  or structure of a file or its tags, and no access to manipulate other stream data.

[TagLib]: http://taglib.github.io/
[taglib-ruby]: https://robinst.github.io/taglib-ruby/
[SWIG]: http://swig.org




