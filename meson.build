project(
    'ddbus',
    'd',
    meson_version: '>=0.50',
    version: '3.0.0',
)

src_inc = include_directories('source')

prefix = get_option('prefix')
include_dir = join_paths(prefix, get_option('includedir'), 'd', 'ddbus')

dbus_dep = dependency('dbus-1')

subdir('source/ddbus')

ddbus_dep = declare_dependency(
    include_directories: src_inc,
    link_with: ddbus_lib
)

