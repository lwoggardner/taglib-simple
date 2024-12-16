#include "conversions.h"
#include <ruby/encoding.h>

using namespace Rice;

namespace TagLib {
    namespace Ruby {

    Object tagLibStringToNonEmptyRubyUTF8String(TagLib::String string) {
        if (string.length() == 0) {
            return {Qnil};
        }
        return { tagLibStringToRubyUTF8String(string) };
    }

    Object uintToNonZeroRubyInteger(unsigned integer) {
        if (integer == 0) {
            return {Qnil};
        }
        return { UINT2NUM(integer) };
    }

    Rice::String tagLibStringToRubyUTF8String(const TagLib::String& str) {
        Rice::String rb_str(str.to8Bit(true));  // true ensures UTF-8
        rb_enc_associate(rb_str.value(), rb_utf8_encoding());
        return rb_str;
    }

    Array tagLibStringListToRuby(const TagLib::StringList& list) {
        Array result;
        for (const auto& str : list) {
            result.push(tagLibStringToRubyUTF8String(str));
        }
        return result;
    }

    Rice::String tagLibByteVectorToRuby(const TagLib::ByteVector& byteVector) {
        // Convert ByteVector to Ruby String with binary encoding
        Rice::String rb_str(std::string(byteVector.data(), byteVector.size()));
        rb_enc_associate(rb_str.value(), rb_ascii8bit_encoding());
        return rb_str;
    }

    Array tagLibByteVectorListToRuby(const TagLib::ByteVectorList& list) {
        Array result;
        for (const auto& byteVector : list) {
            result.push(tagLibByteVectorToRuby((byteVector)));
        }
        return result;
    }

    Hash tagLibPropertyMapToRubyHash(const TagLib::PropertyMap& properties) {
         Hash result;
         // Iterate through the PropertyMap
         for(auto & property : properties) {

             Rice::String key = tagLibStringToRubyUTF8String(property.first);

             // Convert the StringList to Ruby Array
             Array values;
             for(const auto& item : property.second) {
               values.push(tagLibStringToRubyUTF8String(item));
             }
             // Add to result hash
             values.freeze();
             result[key] = values;
         }

         result.freeze();
         return result;
     }
#if (TAGLIB_MAJOR_VERSION >= 2)
    Object taglibVariantToRuby(const TagLib::Variant &value);

    Hash taglibVariantMapToRuby(const TagLib::Map<TagLib::String, TagLib::Variant> & map) {
        Hash result;
        for (const auto& pair : map) {
            Rice::String key(pair.first.toCString());
            const TagLib::Variant& value = pair.second;
            result[key] = taglibVariantToRuby(value);
        }
        return result;
    }

    Array taglibVariantListToRuby(const TagLib::List<TagLib::Variant> & list) {
        Array result;
        for (const auto& item : list) {
            result.push(taglibVariantToRuby(item));
        }
        return result;
    }

    Object taglibVariantToRuby(const TagLib::Variant &value) {
        switch (value.type()) {
            case TagLib::Variant::Bool:
                return value.toBool() ? Qtrue : Qfalse;
            case TagLib::Variant::Int:
                return INT2NUM(value.toInt());
            case TagLib::Variant::UInt:
                return UINT2NUM(value.toUInt());
            case TagLib::Variant::LongLong:
                return LL2NUM(value.toLongLong());
            case TagLib::Variant::ULongLong:
                return ULL2NUM(value.toULongLong());
            case TagLib::Variant::String:
                return { tagLibStringToRubyUTF8String(value.toString()) };
            case TagLib::Variant::StringList:
                return { tagLibStringListToRuby(value.toStringList()) };
            case TagLib::Variant::ByteVector:
                return { tagLibByteVectorToRuby(value.toByteVector()) };
            case TagLib::Variant::ByteVectorList:
                return { tagLibByteVectorListToRuby(value.toByteVectorList()) };
            case TagLib::Variant::VariantList:
                return { taglibVariantListToRuby(value.toList()) };
            case TagLib::Variant::VariantMap:
                return { taglibVariantMapToRuby(value.toMap()) };
            default:
               return Qnil;
        }
    }

    Array tagLibComplexPropertyToRuby(const TagLib::List<TagLib::VariantMap>& list) {
        Array result;

        for (const auto& variantMap : list) {
            result.push(taglibVariantMapToRuby(variantMap));
        }

        return result;
    }
#endif
    }
}
