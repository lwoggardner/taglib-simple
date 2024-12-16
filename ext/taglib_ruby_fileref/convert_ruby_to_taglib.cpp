#include "conversions.h"

using namespace Rice;

namespace TagLib {
  namespace Ruby {

    TagLib::AudioProperties::ReadStyle rubyObjectToTagLibAudioPropertiesReadStyle(const Object& readStyle) {
      if (!readStyle.test()) {
        return TagLib::AudioProperties::Average;
      }
      const Symbol readStyleSym = {readStyle};
      if (readStyleSym.str() == "fast") {
        return TagLib::AudioProperties::Fast;
      }
      if (readStyleSym.str() == "accurate") {
        return TagLib::AudioProperties::Accurate;
      }
      if (readStyleSym.str() == "average") {
        return TagLib::AudioProperties::Average;
      }
        throw Rice::Exception(rb_eArgError, "Invalid read style: %s", readStyleSym.str());
    }

    String rubyStringOrNilToTagLibString(Object value) {
        if (value.is_nil()) {
            return { "", String::UTF8 };
        }
        return rubyStringToTagLibString(value);
    }

    unsigned int rubyIntegerOrNilToUInt(Object value) {

        if (value.is_nil()) {
            return 0;
        }
        return NUM2UINT(value);
    }

      static const rb_encoding* const UTF16LE_ENCODING = rb_enc_find("UTF-16LE");
      static const rb_encoding* const UTF16BE_ENCODING = rb_enc_find("UTF-16BE");
      static const rb_encoding* const UTF16_ENCODING = rb_enc_find("UTF-16");
      static const rb_encoding* const LATIN1_ENCODING = rb_enc_find("ISO-8859-1");


      TagLib::String rubyStringToTagLibString(const Rice::String& str) {
          rb_encoding* enc = rb_enc_get(str);
          if (enc == rb_utf8_encoding()) {
              return { str.c_str(), TagLib::String::UTF8 };
          } else if (enc == rb_ascii8bit_encoding() || enc == rb_usascii_encoding()) {
              return { str.c_str(), TagLib::String::UTF8 };
          } else if (enc == LATIN1_ENCODING) {
              return { str.c_str(), TagLib::String::Latin1 };
          } else if (enc == UTF16LE_ENCODING) {
              return { str.c_str(), TagLib::String::UTF16LE };
          } else if (enc == UTF16BE_ENCODING) {
              return { str.c_str(), TagLib::String::UTF16BE };
          } else {
              // For any other encoding, convert to UTF-8 first
              Rice::String utf8_str = rb_str_export_to_enc(str, rb_utf8_encoding());
              return { utf8_str.c_str(), TagLib::String::UTF8 };
          }
      }

    TagLib::StringList rubyObjectToTagLibStringList(const Object& obj) {
      TagLib::StringList string_list;

      // Handle both String and Array values
      if (TYPE(obj) == T_ARRAY) {
        Array val_array(obj);
        if (val_array.size() > 0) {
          for (auto it = val_array.begin(); it != val_array.end(); ++it) {
            Rice::String item(it->value());
            string_list.append(TagLib::String(item.c_str()));
          }
        }
      } else {
        string_list.append(Rice::String(obj).c_str());
      }
      return string_list;
    }

    bool isBinaryEncoding(const Rice::String& str) {
      return rb_enc_get(str) ==  rb_ascii8bit_encoding();
    }

    TagLib::StringList rubyArrayToTagLibStringList(Array arr) {
      TagLib::StringList stringList;
      for (const auto& item : arr) {
        Rice::String str = {item.value() };
        stringList.append(TagLib::String(str.c_str(), TagLib::String::UTF8));
      }
      return stringList;
    }

    TagLib::ByteVectorList rubyArrayToTagLibByteVectorList(Array arr) {
      TagLib::ByteVectorList list;
      for (const auto& item : arr) {
        Rice::String str = {item.value() };
        list.append(TagLib::ByteVector(str.c_str(), str.length()));
      }
      return list;
    }

#if (TAGLIB_MAJOR_VERSION >= 2)
    TagLib::Variant rubyObjectToTagLibVariant(Object &obj);

    // This can be a StringList, a ByteVectorList or a List<Variant>
    TagLib::Variant rubyArrayToTagLibVariant(Array arr) {
        if (arr.size() == 0) {
            return {};
        }
        Object first = arr[0];

        // Check only first element to determine list type
        if (first.is_a(rb_cString)) {
            Rice::String first_str = Rice::String(first);
            if (isBinaryEncoding(first_str)) {
                return { rubyArrayToTagLibByteVectorList(arr) };
            }
            return { rubyArrayToTagLibStringList(arr) };
        }

        TagLib::List<TagLib::Variant> variantList;
        for (const auto& item : arr) {
            Rice::Object obj = { item.value() };
            variantList.append(rubyObjectToTagLibVariant(obj));
        }
        return { variantList };
    }


    TagLib::Variant rubyStringToTaglibVariant(const Rice::String& str) {
        if (isBinaryEncoding(str)) {
            // Binary string - convert to ByteVector
            return { TagLib::ByteVector(str.c_str(), str.length()) };
        } else {
            // Assume UTF-8 for all other encodings
            return { TagLib::String(str.c_str(), TagLib::String::UTF8) };
        }
    }

    TagLib::VariantMap rubyHashToTagLibVariantMap(const Hash& hash) {
        TagLib::VariantMap result;

        for (auto it = hash.begin(); it != hash.end(); ++it) {
            TagLib::String key(Rice::String(it->first).c_str());
            Rice::Object obj(it->second);
            result.insert(key, rubyObjectToTagLibVariant(obj));
        }

        return result;
    }

    TagLib::Variant rubyObjectToTagLibVariant(Object &obj) {
        if (obj.is_nil()) {
            return {};
        }

        if (obj.is_a(rb_cInteger)) {
            return {NUM2LL(obj.value())};
        }

        if (obj.is_a(rb_cString)) {
            return rubyStringToTaglibVariant(Rice::String(obj));
        }

        if (obj.is_a(rb_cArray)) {
            return rubyArrayToTagLibVariant(Array(obj));
        }

        if (obj.is_a(rb_cHash)) {
            return { rubyHashToTagLibVariantMap(Hash(obj)) };
        }

        if (obj.value() == Qtrue) {
            return {true};
        }

        if (obj.value() == Qfalse) {
            return {false};
        }

        return {};
    }

    // This is used to set complex properties where the input must be Array<Hash>
    TagLib::List<TagLib::VariantMap> rubyObjectToTagLibComplexProperty(const Object& obj) {

        if (!obj.test()) {
          return {};
        }

        Array list(obj);
        TagLib::List<TagLib::VariantMap> result;
        for (auto it = list.begin(); it != list.end(); ++it) {
            result.append(rubyHashToTagLibVariantMap(Hash(it->value())));
        }

        return result;
    }
#endif

  }
}