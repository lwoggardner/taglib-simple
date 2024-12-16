
#include "IOStream.hpp"
#include <rice/rice.hpp>
#include <utility>
#include <taglib/tiostream.h>
#include <taglib/tbytevector.h>
#include <ruby/io.h>

using namespace Rice;
namespace TagLib {
namespace Ruby {

    IOStream::IOStream(Object ruby_io) : io(std::move(ruby_io)) {
        // Only things like File that have a writable? method are considered writable
        // There are techniques to use write-nonblock etc to do this, but callers using custom streams
        // will have to work that out themselves
        openReadOnly = ruby_io.respond_to("writable?") && ruby_io.call("writable?").test();
    };

    IOStream::~IOStream() = default;

    bool IOStream::isIO(const Object& io) {
       return io.respond_to("tell") && io.respond_to("seek") && io.respond_to("read");
    }

    TagLib::FileName IOStream::name() const {
        return io.to_s().c_str();
    }

    TagLib::ByteVector IOStream::readBlock(unsigned long length) {
        // Call read method on Ruby IO object
        Object result = io.call("read", (long)length);

        if (result.is_nil()) {
            return {};
        }

        Rice::String str = Rice::String(result);
        return {str.c_str(), static_cast<unsigned int>(str.length())};
    }


    void IOStream::writeBlock(const TagLib::ByteVector &data) {
        // Convert ByteVector to Ruby string and write
        std::string str(data.data(), data.size());
        io.call("write", Rice::String(str));
    }

     void IOStream::insert(const TagLib::ByteVector &data, v1_unsigned_offset_type start, size_type replace) {
        seek(start, Beginning);
        // If replacing content, first read the content after the replace section
        Rice::String remainder;
        if (replace > 0) {
            seek(static_cast<offset_type>(replace), Current);
            remainder = io.call("read");
        }

        // Seek back and write new data
        seek(start, Beginning);
        writeBlock(data);

        // Write remaining content if any
        if (!remainder.is_nil()) {
            // Write the Ruby string directly back to the IO
            (void)io.call("write", remainder);
        }

        size_type new_length = start + data.size();
        if (!remainder.is_nil()) {
            new_length += remainder.length();
        }

        truncate(static_cast<offset_type>(new_length));
    }

     void IOStream::removeBlock(const v1_unsigned_offset_type start, const size_type length) {
        // Read the content after the section to remove
        seek(static_cast<offset_type>(start + length), Beginning);
        Rice::String remainder = io.call("read");

        // Seek back to start position
        seek(start, Beginning);

        // Write the remaining content if any
        if (!remainder.is_nil()) {
            (void) io.call("write", remainder);
        }

        truncate(static_cast<long>(start + remainder.length()));
    }

    bool IOStream::readOnly() const {
        return openReadOnly;
    }
    bool IOStream::isOpen() const {
        // Check if the file is open using Ruby's closed? method
        return !io.call("closed?").test();
    }

    void IOStream::seek(offset_type offset, Position p) {
        int whence;
        switch(p) {
            case Beginning:
                whence = SEEK_SET;
                break;
            case Current:
                whence = SEEK_CUR;
                break;
            case End:
                whence = SEEK_END;
                break;
            default:
                whence = SEEK_SET;
        }

        (void) io.call("seek", offset, whence);
    }

     offset_type IOStream::tell() const {
        return NUM2LONG(io.call("tell"));
    }

     offset_type IOStream::length() {
        // Store current position
        const offset_type current = tell();

        // Seek to end to get length
        seek(0, End);
        const offset_type file_length = tell();

        // Restore original position
        seek(current, Beginning);

        return file_length;
    }

    void IOStream::clear() {
      //nothing to do on ruby IO
    }

    // Truncate if necessary
    // TODO: Truncate is defined on file, but not on IO
    // but other kinds of streams are not rewritable like this anyway.
    void IOStream::truncate(offset_type length) {
       (void) io.call("truncate", length);
    }
}
}