project(
    'ddbus',
    'd',
    meson_version: '>=0.50',
    version: '3.0.0',
)

src_inc = include_directories('source')

prefix = get_option('prefix')
include_dir = join_paths(prefix, get_option('includedir'), 'd', 'apk-polkit')

dbus_dep = dependency('dbus-1')

subdir('source/ddbus')
