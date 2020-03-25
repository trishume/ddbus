lib_src = [
    'attributes.d',
    'bus.d',
    'c_lib.d',
    'conv.d',
    'exception.d',
    'package.d',
    'router.d',
    'simple.d',
    'thin.d',
    'util.d',
]

ddbus_lib = library(
    'ddbus',
    lib_src,
    version: meson.project_version(),
    install: true,
    include_directories: src_inc,
)

pkgc = import('pkgconfig')

pkgc.generate(
    ddbus_lib,
    subdirs: 'd/ddbus',
    requires: dbus_dep,
)

install_headers(
    lib_src,
    subdir: 'd/ddbus/ddbus',
)
