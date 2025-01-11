
#include "FileRef.hpp"
#if TAGLIB_MAJOR_VERSION > 1
#include <taglib/tversionnumber.h>
#endif

extern "C"
void Init_taglib_simple_fileref() {
    Module rb_mTagLib = define_module("TagLib");
    Module rb_mTagLibExt = define_module_under({rb_mTagLib},"Simple");

    define_taglib_simple_fileref(rb_mTagLibExt);

    uint major;
    uint minor;
    uint patch;
    Rice::String version;

#if TAGLIB_MAJOR_VERSION == 1
    // Taglib 1 does not have runtime version information
    major = TAGLIB_MAJOR_VERSION;
    minor = TAGLIB_MINOR_VERSION;
    patch = TAGLIB_PATCH_VERSION;

    version = Rice::String::format("%d.%d.%d", TAGLIB_MAJOR_VERSION, TAGLIB_MINOR_VERSION, TAGLIB_PATCH_VERSION);
#else

    TagLib::VersionNumber runtime_version = TagLib::runtimeVersion();

    major = runtime_version.majorVersion();
    minor = runtime_version.minorVersion();
    patch = runtime_version.patchVersion();
    version = runtime_version.toString().toCString();

    // Fatal error on major version mismatch
    if (TAGLIB_MAJOR_VERSION != runtime_version.majorVersion()) {
        rb_raise(rb_eLoadError,
        "Incompatible TagLib version. Compiled with %d.%d.%d but loaded %s",
            TAGLIB_MAJOR_VERSION, TAGLIB_MINOR_VERSION, TAGLIB_PATCH_VERSION, version.c_str());

    }

    // Warning if compiled against a minor version that is newer than the runtime library
    if (TAGLIB_MINOR_VERSION > runtime_version.minorVersion()) {
        rb_warn(
            "TagLib runtime version %s is older than compile-time version %d.%d.%d",
            version.c_str(), TAGLIB_MAJOR_VERSION, TAGLIB_MINOR_VERSION, TAGLIB_PATCH_VERSION
            );
    }
#endif

    rb_mTagLib.const_set("MAJOR_VERSION", UINT2NUM(major));
    rb_mTagLib.const_set("MINOR_VERSION", UINT2NUM(minor));
    rb_mTagLib.const_set("PATCH_VERSION", UINT2NUM(patch));
    rb_mTagLib.const_set("LIBRARY_VERSION", {version});

}
