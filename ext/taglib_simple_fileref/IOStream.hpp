#pragma once

#include "taglib_wrap.h"
#include <taglib/tiostream.h>
#include <rice/rice.hpp>

using namespace Rice;

namespace TagLib {
    namespace Simple {

#if (TAGLIB_MAJOR_VERSION >= 2)
        // V2 looks to have aligned with posix
        using offset_type = offset_t;
        using size_type = size_t;
        // V1 had some unsigned offsets
        using v1_unsigned_offset_type = offset_t;
#else
        using offset_type = long;
        using size_type = unsigned long;
        using v1_unsigned_offset_type = unsigned long;
#endif


        // An TagLib::IOStream from Ruby IO
        class IOStream final : public TagLib::IOStream  {
            Object io;
        public:
            static bool isIO(const Object& io);
            bool openReadOnly;
            explicit IOStream(Object ruby_io);

            ~IOStream() override;
            FileName name() const override;
            ByteVector readBlock(unsigned long length) override;
            void writeBlock(const ByteVector &data) override;
            void insert(const ByteVector &data, v1_unsigned_offset_type start, size_type replace) override;
            void removeBlock(v1_unsigned_offset_type start, size_type length) override;
            void seek(offset_type offset, Position p) override;
            void clear() override;
            offset_type tell() const override;
            offset_type length() override;
            void truncate(offset_type length) override;
            bool isOpen() const override;
            bool readOnly() const override;
        };
    } // Ruby
} // TagLib