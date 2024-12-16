
#include "FileRef.hpp"

extern "C"
void Init_taglib_ruby_fileref() {
    Module rb_mTagLib = define_module("TagLib");
    Module rb_mTagLibExt = define_module_under(rb_mTagLib,"Ruby");
    define_taglib_ruby_fileref(rb_mTagLibExt);
    rb_mTagLib.const_set("MAJOR_VERSION", UINT2NUM(TAGLIB_MAJOR_VERSION));
    rb_mTagLib.const_set("MINOR_VERSION", UINT2NUM(TAGLIB_MINOR_VERSION));
    rb_mTagLib.const_set("PATCH_VERSION", UINT2NUM(TAGLIB_PATCH_VERSION));
}
