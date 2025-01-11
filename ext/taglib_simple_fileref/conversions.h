// Type conversations from ruby to taglib
#pragma once

#include "taglib_wrap.h"
#include <rice/rice.hpp>
#include <ruby/encoding.h>
#include <taglib/audioproperties.h>
#include <taglib/tstringlist.h>
#if (TAGLIB_MAJOR_VERSION >=2)
#include <taglib/tvariant.h>
#endif

#include <taglib/tpropertymap.h>

using namespace Rice;

namespace TagLib {
   namespace Simple {
      // taglib to ruby
      Rice::Object tagLibStringToNonEmptyRubyUTF8String(TagLib::String string);
      Rice::Object uintToNonZeroRubyInteger(unsigned integer);
      Rice::Hash tagLibPropertyMapToRubyHash(const TagLib::PropertyMap& properties);
      Array tagLibStringListToRuby(const TagLib::StringList& list);
      Rice::String tagLibStringToRubyUTF8String(const TagLib::String& str);

      // ruby to taglib
      TagLib::String rubyStringOrNilToTagLibString(Object value);
      unsigned int rubyIntegerOrNilToUInt(Object value);
      TagLib::String rubyStringToTagLibString(const Rice::String& str);
      TagLib::AudioProperties::ReadStyle rubyObjectToTagLibAudioPropertiesReadStyle(const Rice::Object& readStyle);
      TagLib::StringList rubyObjectToTagLibStringList(const Rice::Object& obj);

#if (TAGLIB_MAJOR_VERSION >= 2)
      Rice::Array tagLibComplexPropertyToRuby(const TagLib::List<TagLib::VariantMap>& list);
      TagLib::List<TagLib::VariantMap> rubyObjectToTagLibComplexProperty(const Rice::Object& obj);
#endif
   }
}