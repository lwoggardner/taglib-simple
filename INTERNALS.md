## How it works under the covers

Uses the [Rice] header only library to create a Ruby c++ extension

### Classes

#### C++ class {TagLib::Simple::FileRef}
- Ruby extension class wrapping [Taglib::FileRef]
- The initial filename (or IO object) is the only Ruby object held in a C++ reference
- When a {TagLib::Simple::FileRef} is closed, the native [TagLib::FileRef] is released, which releases memory and file handles.
- Simple Ruby objects are used for all output.
    - Memory content is copied, not shared
    - No native TagLib objects are exposed to Ruby
    - Immutable `Data` objects are used to represent [TagLib::Tag] and [TagLib::AudioProperties]
    - Everything else is converted to String(UTF8 or binary), Integer, Array or Hash.
- Mutating interfaces all take Hash input to avoid exposing the complexity of the underlying TagLib structures.
- Can be used directly if preferred over {TagLib::MediaFile}.

#### C++ class TagLib::Simple::IOStream (private)
- Implements the abstract [TagLib::IOStream] interface over anything
  that quacks like a ruby IO and that is provided to {TagLib::Simple::FileRef} constructor instead of a plain string
  file name.

#### Ruby class {TagLib::MediaFile}
- Wraps {TagLib::Simple::FileRef} with a more idiomatic Ruby interface.
- Quacks like a Hash where:
    - Symbol keys represent entries from Tag and AudioProperties
    - String keys represent keys into [TagLib::PropertyMap] or complex properties, e.g., 'TITLE', 'ARTIST'.
    - Values are Array of String when retrieved from the underlying [TagLib::PropertyMap] structure.
    - Values are Array of Hash, when retrieved as 'complex properties', eg 'PICTURE'.
- Quacks like the underlying [TagLib::Tag] with attribute getters/setters the well known tags.
- Provides attribute like getters/setters for arbitrary tags via `#method_missing`
- Holds all the pending tag updates in a Hash instance variable and only passing them back to C++ on save. 

[Rice]: https://ruby-rice.github.io/
[Taglib::FileRef]: https://taglib.org/api/classTagLib_1_1FileRef.html
[TagLib::Tag]: https://taglib.org/api/classTagLib_1_1Tag.html
[TagLib::AudioProperties]: https://taglib.org/api/classTagLib_1_1AudioProperties.html
[TagLib::PropertyMap]: https://taglib.org/api/classTagLib_1_1PropertyMap.html
[TagLib::IOStream]: https://taglib.org/api/classTagLib_1_1IOStream.html