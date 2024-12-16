#pragma once

#include "taglib_wrap.h"
#include <taglib/fileref.h>
#include <rice/rice.hpp>

// Specialised constructor template to avoid the Director constructor that matches Object as first argument.
// The use of TagLib::FileRef here is arbitrary
template<typename T, typename... Arg_Ts>
class Rice::Constructor<T, TagLib::FileRef, Arg_Ts...> {
public:
 static void construct(VALUE self, Arg_Ts... args) {
  T *data = new T(args...);
  detail::replace<T>(self, Data_Type<T>::ruby_data_type(), data, true);
 }
};

using namespace Rice;

// @!yard module TagLib
namespace TagLib {
 // @!yard module Ruby
 namespace Ruby {
  /** @!yard
   * # C++ extension wrapping underlying TagLib::FileRef so we can interact with it using Ruby objects
   * class FileRef
   */
  class FileRef final {
   std::unique_ptr<TagLib::FileRef> fileRef;
   std::unique_ptr<IOStream> stream;

  public:
   /** @!yard
    # Create a FileRef from a file or stream
    # @param [String|:to_path|IO] file_or_stream
    #    A file name or an io like object responding to :read, :seek and :tell
    # @param [Symbol<:average,:fast, :accurate>|nil] read_audio_properties
    #   :fast, :accurate, :average indicator for reading audio properties. nil/false to skip
    def initialize(file_or_stream, read_audio_properties = nil); end
   */
   explicit FileRef(Object fileOrStream, Object readAudioProperties = Qnil);

   ~FileRef() = default;

   // Prevent copying
   FileRef(const FileRef &) = delete;

   FileRef &operator=(const FileRef &) = delete;

   /** @!yard
    # release file descriptors opened and held by TagLib
    # @note does not close the input IO object (since we didn't open it)
    # @return [void]
    def close(); end
   */
   void close();

   /** @!yard
    # Underlying stream is open for reading
    # @return [Boolean]
    def valid?; end
   */
   bool isValid() const;

   /** @!yard
    # Is the underlying stream readonly (ie cannot update tags etc...)
    # @return [Boolean]
    def read_only?; end
   */
   bool isReadOnly() const;

   /** @!yard
    # @!group Reading Properties

    # @return [AudioProperties] properties of the audio stream
    # @return [nil] audio properties were not requested at {#initialize}
    def audio_properties; end
   */
   Object audioProperties() const;

   /** @!yard
    # @return [AudioTag] normalised subset of well known tags
    def tag; end
   */
   Object tag() const;

   /** @!yard
    # @return [Hash<String, Array<String>>] arbitrary String properties
    def properties; end
   */
   Hash properties() const;

   /** @!yard
    # Retrieve a complex property
    # @param [String] key the complex property to retrieve
    # @return [Array<Hash<String>>] a list of complex property values for this key
    #   empty if the property does not exist
    # @since TagLib 2.x
    def complex_property(key); end
   */
   Array complexProperty(Rice::String key) const;

   /** @!yard
    # @return [Array<String>] list of complex properties available in this stream
    # @since TagLib 2.x
    def complex_property_keys; end
   */
   Array complexPropertyKeys() const;

   /** @!yard
    # @!endgroup
    # @!group Writing Properties

    # @param [Hash<String,Array<String>>] props input properties to merge
    # @param [Boolean] replace_all true will clear all existing properties, otherwise the input Hash
    #   is merged with existing properties
    # @return [void]
    def merge_properties(props, replace_all = false); end
   */
   void mergeProperties(Hash props, bool replace_all = false) const;

   /** @!yard
    # @param [Hash<Symbol, String|Integer>|AudioTag] props input tag properties to merge.
    #   keys must be a subset of {AudioTag} members
    # @return [void]
    def merge_tag_properties(props); end
   */
   void mergeTagProperties(Object props) const;

   /** @!yard
    # @!method merge_complex_properties(props, replace_all)
    # @param [Hash<String,Array<Hash<String,Object>>>] props Map of complex property name to new list of
    #   complex property values
    # @param [Boolean] replace_all true will clear all existing complex properties before merging
    # @since TagLib 2.x
    # @return [void]

    # @!endgroup
   */
   void mergeComplexProperties(Hash in, bool replace_all = false) const;

   Rice::String toString() const;

   Rice::String inspect() const;

   /** @!yard
    # Save updates back to the underlying file or stream
    # @return [void]
    def save; end
   */
   void save() const;

  private:
   void raiseInvalid() const;
  };

  //@!yard end # FileRef
 }

 //@!yard end # Ruby
}

//@!yard end # TagLib
void define_taglib_ruby_fileref(const Module &rb_mTagLibRuby);
