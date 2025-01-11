//
// Created by ggardner on 17/11/24.
//

#include "FileRef.hpp"
#include "IOStream.hpp"
#include <rice/rice.hpp>
#include "conversions.h"
#include <taglib/tpropertymap.h>
#include <taglib/tstring.h>

using namespace Rice;

namespace TagLib {
    namespace Simple {
        FileRef::FileRef(const Object fileOrStream, const Object readAudioProperties) : fileRef(nullptr), stream(nullptr) {
            TagLib::AudioProperties::ReadStyle style = rubyObjectToTagLibAudioPropertiesReadStyle(readAudioProperties);

            if (IOStream::isIO(fileOrStream)) {
                // Handle IO object inputObject
                stream = std::make_unique<IOStream>(fileOrStream);
                fileRef = std::make_unique<TagLib::FileRef>(stream.get(), readAudioProperties.test(), style);
                if (fileRef->isNull())
                    // unable to read the stream.
                        stream.reset();
            } else {
                Rice::String pathStr;
                // PathName
                if (fileOrStream.respond_to("to_path")) {
                    pathStr = Rice::String(fileOrStream.call("to_path"));
                } else if (fileOrStream.is_a(rb_cString)) {
                    pathStr = Rice::String(fileOrStream);
                } else {
                    throw Exception(rb_eTypeError, "expects String, Pathname or IO, got %s", fileOrStream.class_name().c_str());
                }
                if (pathStr.length() > 0) {
                    TagLib::FileName fn(pathStr.c_str());
                    fileRef = std::make_unique<TagLib::FileRef>(fn, readAudioProperties.test(), style);
                } else {
                    fileRef = std::make_unique<TagLib::FileRef>();
                }
            }
        }

        void FileRef::close()
        {
            if (!fileRef->isNull()) {
                // delete the TagLib::FileRef, closing streams and release file descriptors held in TagLib C++
                fileRef = std::make_unique<TagLib::FileRef>();
                // note we do NOT close the IO object since we did not open it!
                stream.reset();
            }
        }

        bool FileRef::isValid() const {
            // isNull checks file isValid too
           return !fileRef->isNull();
        }

        bool FileRef::isReadOnly() const {
            raiseInvalid();
            return fileRef->file()->readOnly();
        }

        Object FileRef::audioProperties() const {
            raiseInvalid();

            const TagLib::AudioProperties* props = fileRef->audioProperties();
            if (!props) {
                return {Qnil};
            }

            // Get the Ruby AudioProperties Data class from TagLib module
            static Object rb_cAudioProperties = Module("TagLib").const_get("AudioProperties");

            // Create new AudioProperties Data instance
            return rb_cAudioProperties.call("new", props->lengthInMilliseconds(), props->bitrate(), props->sampleRate(), props->channels() );
        }

        Object FileRef::tag() const {
            raiseInvalid();

            const TagLib::Tag* tag = fileRef->tag();
            if (!tag) {
                //this never seems to happen but protect anyway
                return {Qnil};
            }

            // Get the Ruby AudioTag Data class from TagLib module
            static Object rb_cAudioTag = Module("TagLib").const_get("AudioTag");

            //  define :title, :artist, :album, :genre, :year, :track, :comment
            return rb_cAudioTag.call("new",
                tagLibStringToNonEmptyRubyUTF8String(tag->title()),
                tagLibStringToNonEmptyRubyUTF8String(tag-> artist()),
                tagLibStringToNonEmptyRubyUTF8String(tag->album()),
                tagLibStringToNonEmptyRubyUTF8String(tag->genre()),
                uintToNonZeroRubyInteger(tag->year()),
                uintToNonZeroRubyInteger(tag->track()),
                tagLibStringToNonEmptyRubyUTF8String(tag->comment())
            );

        }

        void FileRef::mergeTagProperties(Object in_obj) const {
            raiseInvalid();

            Hash in = in_obj.call("to_h");
            for (Hash::const_iterator it = in.begin(); it != in.end(); ++it) {
                auto key = Symbol(it->key).str();
                const Object value(it->value);
                if (key == "title") {
                    fileRef->tag()->setTitle(rubyStringOrNilToTagLibString(value));
                }
                else if (key == "artist") {
                    fileRef->tag()->setArtist(rubyStringOrNilToTagLibString(value));
                }
                else if (key == "album") {
                    fileRef->tag()->setAlbum(rubyStringOrNilToTagLibString(value));
                }
                else if (key == "comment") {
                    fileRef->tag()->setComment(rubyStringOrNilToTagLibString(value));
                }
                else if (key == "genre") {
                    fileRef->tag()->setGenre(rubyStringOrNilToTagLibString(value));
                }
                else if (key == "year") {
                    fileRef->tag()->setYear(rubyIntegerOrNilToUInt(value));
                }
                else if (key == "track") {
                    fileRef->tag()->setTrack(rubyIntegerOrNilToUInt(value));
                } else {
                    throw Exception(rb_eKeyError, "Unknown tag property: ", key);
                }

            }
        }


        Hash FileRef::properties() const {
            raiseInvalid();
            return tagLibPropertyMapToRubyHash(fileRef->file()->properties());
        }

        void FileRef::mergeProperties(Hash in, const bool replace_all) const {
            raiseInvalid();

            TagLib::PropertyMap properties;
            if (!replace_all) {
                properties = fileRef->file()->properties();
            }

            for (const auto& pair : in) {
                properties.replace(
                    rubyStringToTagLibString(pair.key),
                    rubyObjectToTagLibStringList(pair.value)
                    );
            }
            properties.removeEmpty();

            // Set the modified properties back to the file
            fileRef->file()->setProperties(properties);
        }

       Rice::String FileRef::toString() const {
            std::string result = "TagLib::Simple::FileRef [";

            if (this->isValid()) {
                result += "io=" + std::string(fileRef->file()->name());
            } else {
                result += "valid=false";
            }

            result += "]";
            return {result};
        }

        Rice::String FileRef::inspect() const {
            std::string result = "TagLib::Simple::FileRef [";

            if (this->isValid()) {
                result += "io='" + std::string(fileRef->file()->name()) + "'";
                result += ", file_type=" + std::string(typeid(*fileRef->file()).name());
                result += ", tag_type=" + std::string(typeid(*fileRef->tag()).name());
            } else {
                result += "valid=false";
            }
            result += "]";
            return {result};
        }

        void FileRef::save() const {
            raiseInvalid();
            fileRef->save();
        }

        void FileRef::raiseInvalid() const {
            if (isValid()) { return; }
            static Object rb_eTagLibError = Module("TagLib").const_get("Error");
            throw Exception(rb_eTagLibError, "Taglib::FileRef is closed or invalid");
        }

        // Complex properties interface


        Array FileRef::complexPropertyKeys() const {
            raiseInvalid();
#if (TAGLIB_MAJOR_VERSION < 2)
            return {};
#else
            return tagLibStringListToRuby(fileRef->complexPropertyKeys());
#endif
        }

        Array FileRef::complexProperty(Rice::String key) const {
            raiseInvalid();
#if (TAGLIB_MAJOR_VERSION < 2)
            throw Rice::Exception(rb_eNotImpError, "Complex properties not available in TagLib %d", TAGLIB_MAJOR_VERSION);
#else
            return tagLibComplexPropertyToRuby(fileRef->complexProperties(rubyStringToTagLibString(key)));
#endif
        }

        void FileRef::mergeComplexProperties(Hash in, const bool replace_all) const {
            raiseInvalid();
#if (TAGLIB_MAJOR_VERSION < 2)
            if (in.size() > 0 ) {
                throw Rice::Exception(rb_eNotImpError, "Complex properties not available in TagLib %d", TAGLIB_MAJOR_VERSION);
            }
#else
            if (replace_all) {;
                for (const auto& item : fileRef->file()->complexPropertyKeys()) {
                   fileRef->file()->setComplexProperties(item,{});
                }
            }

            for (const auto& pair : in) {
                fileRef->file()->setComplexProperties(
                    rubyStringToTagLibString(pair.key),
                    rubyObjectToTagLibComplexProperty(pair.value)
                );
            }
#endif
        }


    }
}

void define_taglib_simple_fileref(const Module& rb_mParent) {

    Data_Type<TagLib::Simple::FileRef> rb_cFileRef = define_class_under<TagLib::Simple::FileRef>( { rb_mParent }, "FileRef")
            .define_constructor(Constructor<TagLib::Simple::FileRef, TagLib::FileRef, Object, Object>(), Arg("file").keepAlive(), Arg("style") = Qnil)
            .define_method("valid?", &TagLib::Simple::FileRef::isValid)
            .define_method("read_only?", &TagLib::Simple::FileRef::isReadOnly)
            .define_method("close", &TagLib::Simple::FileRef::close)
            .define_method("audio_properties", &TagLib::Simple::FileRef::audioProperties)
            .define_method("properties", &TagLib::Simple::FileRef::properties)
            .define_method("tag", &TagLib::Simple::FileRef::tag)
            .define_method("merge_properties", &TagLib::Simple::FileRef::mergeProperties,Arg("h"),Arg("r") = false)
            .define_method("merge_tag_properties", &TagLib::Simple::FileRef::mergeTagProperties, Arg("h"))
            .define_method("save", &TagLib::Simple::FileRef::save)
            .define_method("to_s", &TagLib::Simple::FileRef::toString)
            .define_method("inspect", &TagLib::Simple::FileRef::inspect)
            .define_method("complex_property", &TagLib::Simple::FileRef::complexProperty, Arg("key"))
            .define_method("complex_property_keys", &TagLib::Simple::FileRef::complexPropertyKeys)
            .define_method("merge_complex_properties", &TagLib::Simple::FileRef::mergeComplexProperties, Arg("h"), Arg("r") = false)
    ;

}