module ddbus.c_lib;

import core.stdc.config;
import core.stdc.stdarg;

// dfmt off

extern (C):
// START dbus/dbus-arch-deps.d
alias c_long dbus_int64_t;
alias c_ulong dbus_uint64_t;
alias int dbus_int32_t;
alias uint dbus_uint32_t;
alias short dbus_int16_t;
alias ushort dbus_uint16_t;
// END dbus/dbus-arch-deps.d
// START dbus/dbus-types.d
alias uint dbus_unichar_t;
alias uint dbus_bool_t;



struct DBus8ByteStruct
{
    dbus_uint32_t first32;
    dbus_uint32_t second32;
}

union DBusBasicValue
{
    ubyte[8] bytes;
    dbus_int16_t i16;
    dbus_uint16_t u16;
    dbus_int32_t i32;
    dbus_uint32_t u32;
    dbus_bool_t bool_val;
    dbus_int64_t i64;
    dbus_uint64_t u64;
    DBus8ByteStruct eight;
    double dbl;
    ubyte byt;
    char* str;
    int fd;
}
// END dbus/dbus-types.d
// START dbus/dbus-protocol.d

// END dbus/dbus-protocol.d
// START dbus/dbus-errors.d
struct DBusError
{
    const(char)* name;
    const(char)* message;
    uint dummy1;
    uint dummy2;
    uint dummy3;
    uint dummy4;
    uint dummy5;
    void* padding1;
}

void dbus_error_init (DBusError* error);
void dbus_error_free (DBusError* error);
void dbus_set_error (DBusError* error, const(char)* name, const(char)* message, ...);
void dbus_set_error_const (DBusError* error, const(char)* name, const(char)* message);
void dbus_move_error (DBusError* src, DBusError* dest);
dbus_bool_t dbus_error_has_name (const(DBusError)* error, const(char)* name);
dbus_bool_t dbus_error_is_set (const(DBusError)* error);
// END dbus/dbus-errors.d
// START dbus/dbus-macros.d

// END dbus/dbus-macros.d
// START dbus/dbus-memory.d
alias void function (void*) DBusFreeFunction;

void* dbus_malloc (size_t bytes);
void* dbus_malloc0 (size_t bytes);
void* dbus_realloc (void* memory, size_t bytes);
void dbus_free (void* memory);
void dbus_free_string_array (char** str_array);
void dbus_shutdown ();
// END dbus/dbus-memory.d
// START dbus/dbus-shared.d
enum DBusBusType
{
    DBUS_BUS_SESSION = 0,
    DBUS_BUS_SYSTEM = 1,
    DBUS_BUS_STARTER = 2
}

enum DBusHandlerResult
{
    DBUS_HANDLER_RESULT_HANDLED = 0,
    DBUS_HANDLER_RESULT_NOT_YET_HANDLED = 1,
    DBUS_HANDLER_RESULT_NEED_MEMORY = 2
}
// END dbus/dbus-shared.d
// START dbus/dbus-address.d
struct DBusAddressEntry;


dbus_bool_t dbus_parse_address (const(char)* address, DBusAddressEntry*** entry, int* array_len, DBusError* error);
const(char)* dbus_address_entry_get_value (DBusAddressEntry* entry, const(char)* key);
const(char)* dbus_address_entry_get_method (DBusAddressEntry* entry);
void dbus_address_entries_free (DBusAddressEntry** entries);
char* dbus_address_escape_value (const(char)* value);
char* dbus_address_unescape_value (const(char)* value, DBusError* error);
// END dbus/dbus-address.d
// START dbus/dbus-syntax.d
dbus_bool_t dbus_validate_path (const(char)* path, DBusError* error);
dbus_bool_t dbus_validate_interface (const(char)* name, DBusError* error);
dbus_bool_t dbus_validate_member (const(char)* name, DBusError* error);
dbus_bool_t dbus_validate_error_name (const(char)* name, DBusError* error);
dbus_bool_t dbus_validate_bus_name (const(char)* name, DBusError* error);
dbus_bool_t dbus_validate_utf8 (const(char)* alleged_utf8, DBusError* error);
// END dbus/dbus-syntax.d
// START dbus/dbus-signature.d
struct DBusSignatureIter
{
    void* dummy1;
    void* dummy2;
    dbus_uint32_t dummy8;
    int dummy12;
    int dummy17;
}

void dbus_signature_iter_init (DBusSignatureIter* iter, const(char)* signature);
int dbus_signature_iter_get_current_type (const(DBusSignatureIter)* iter);
char* dbus_signature_iter_get_signature (const(DBusSignatureIter)* iter);
int dbus_signature_iter_get_element_type (const(DBusSignatureIter)* iter);
dbus_bool_t dbus_signature_iter_next (DBusSignatureIter* iter);
void dbus_signature_iter_recurse (const(DBusSignatureIter)* iter, DBusSignatureIter* subiter);
dbus_bool_t dbus_signature_validate (const(char)* signature, DBusError* error);
dbus_bool_t dbus_signature_validate_single (const(char)* signature, DBusError* error);
dbus_bool_t dbus_type_is_valid (int typecode);
dbus_bool_t dbus_type_is_basic (int typecode);
dbus_bool_t dbus_type_is_container (int typecode);
dbus_bool_t dbus_type_is_fixed (int typecode);
// END dbus/dbus-signature.d
// START dbus/dbus-misc.d
char* dbus_get_local_machine_id ();
void dbus_get_version (int* major_version_p, int* minor_version_p, int* micro_version_p);
dbus_bool_t dbus_setenv (const(char)* variable, const(char)* value);
// END dbus/dbus-misc.d
// START dbus/dbus-threads.d
alias DBusMutex* function () DBusMutexNewFunction;
alias void function (DBusMutex*) DBusMutexFreeFunction;
alias uint function (DBusMutex*) DBusMutexLockFunction;
alias uint function (DBusMutex*) DBusMutexUnlockFunction;
alias DBusMutex* function () DBusRecursiveMutexNewFunction;
alias void function (DBusMutex*) DBusRecursiveMutexFreeFunction;
alias void function (DBusMutex*) DBusRecursiveMutexLockFunction;
alias void function (DBusMutex*) DBusRecursiveMutexUnlockFunction;
alias DBusCondVar* function () DBusCondVarNewFunction;
alias void function (DBusCondVar*) DBusCondVarFreeFunction;
alias void function (DBusCondVar*, DBusMutex*) DBusCondVarWaitFunction;
alias uint function (DBusCondVar*, DBusMutex*, int) DBusCondVarWaitTimeoutFunction;
alias void function (DBusCondVar*) DBusCondVarWakeOneFunction;
alias void function (DBusCondVar*) DBusCondVarWakeAllFunction;



enum DBusThreadFunctionsMask
{
    DBUS_THREAD_FUNCTIONS_MUTEX_NEW_MASK = 1,
    DBUS_THREAD_FUNCTIONS_MUTEX_FREE_MASK = 2,
    DBUS_THREAD_FUNCTIONS_MUTEX_LOCK_MASK = 4,
    DBUS_THREAD_FUNCTIONS_MUTEX_UNLOCK_MASK = 8,
    DBUS_THREAD_FUNCTIONS_CONDVAR_NEW_MASK = 16,
    DBUS_THREAD_FUNCTIONS_CONDVAR_FREE_MASK = 32,
    DBUS_THREAD_FUNCTIONS_CONDVAR_WAIT_MASK = 64,
    DBUS_THREAD_FUNCTIONS_CONDVAR_WAIT_TIMEOUT_MASK = 128,
    DBUS_THREAD_FUNCTIONS_CONDVAR_WAKE_ONE_MASK = 256,
    DBUS_THREAD_FUNCTIONS_CONDVAR_WAKE_ALL_MASK = 512,
    DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_NEW_MASK = 1024,
    DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_FREE_MASK = 2048,
    DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_LOCK_MASK = 4096,
    DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_UNLOCK_MASK = 8192,
    DBUS_THREAD_FUNCTIONS_ALL_MASK = 16383
}

struct DBusThreadFunctions
{
    uint mask;
    DBusMutexNewFunction mutex_new;
    DBusMutexFreeFunction mutex_free;
    DBusMutexLockFunction mutex_lock;
    DBusMutexUnlockFunction mutex_unlock;
    DBusCondVarNewFunction condvar_new;
    DBusCondVarFreeFunction condvar_free;
    DBusCondVarWaitFunction condvar_wait;
    DBusCondVarWaitTimeoutFunction condvar_wait_timeout;
    DBusCondVarWakeOneFunction condvar_wake_one;
    DBusCondVarWakeAllFunction condvar_wake_all;
    DBusRecursiveMutexNewFunction recursive_mutex_new;
    DBusRecursiveMutexFreeFunction recursive_mutex_free;
    DBusRecursiveMutexLockFunction recursive_mutex_lock;
    DBusRecursiveMutexUnlockFunction recursive_mutex_unlock;
    void function () padding1;
    void function () padding2;
    void function () padding3;
    void function () padding4;
}

struct DBusCondVar;


struct DBusMutex;


dbus_bool_t dbus_threads_init (const(DBusThreadFunctions)* functions);
dbus_bool_t dbus_threads_init_default ();
// END dbus/dbus-threads.d
// START dbus/dbus-message.d
struct DBusMessageIter
{
    void* dummy1;
    void* dummy2;
    dbus_uint32_t dummy3;
    int dummy4;
    int dummy5;
    int dummy6;
    int dummy7;
    int dummy8;
    int dummy9;
    int dummy10;
    int dummy11;
    int pad1;
    int pad2;
    void* pad3;
}

struct DBusMessage;


DBusMessage* dbus_message_new (int message_type);
DBusMessage* dbus_message_new_method_call (const(char)* bus_name, const(char)* path, const(char)* iface, const(char)* method);
DBusMessage* dbus_message_new_method_return (DBusMessage* method_call);
DBusMessage* dbus_message_new_signal (const(char)* path, const(char)* iface, const(char)* name);
DBusMessage* dbus_message_new_error (DBusMessage* reply_to, const(char)* error_name, const(char)* error_message);
DBusMessage* dbus_message_new_error_printf (DBusMessage* reply_to, const(char)* error_name, const(char)* error_format, ...);
DBusMessage* dbus_message_copy (const(DBusMessage)* message);
DBusMessage* dbus_message_ref (DBusMessage* message);
void dbus_message_unref (DBusMessage* message);
int dbus_message_get_type (DBusMessage* message);
dbus_bool_t dbus_message_set_path (DBusMessage* message, const(char)* object_path);
const(char)* dbus_message_get_path (DBusMessage* message);
dbus_bool_t dbus_message_has_path (DBusMessage* message, const(char)* object_path);
dbus_bool_t dbus_message_set_interface (DBusMessage* message, const(char)* iface);
const(char)* dbus_message_get_interface (DBusMessage* message);
dbus_bool_t dbus_message_has_interface (DBusMessage* message, const(char)* iface);
dbus_bool_t dbus_message_set_member (DBusMessage* message, const(char)* member);
const(char)* dbus_message_get_member (DBusMessage* message);
dbus_bool_t dbus_message_has_member (DBusMessage* message, const(char)* member);
dbus_bool_t dbus_message_set_error_name (DBusMessage* message, const(char)* name);
const(char)* dbus_message_get_error_name (DBusMessage* message);
dbus_bool_t dbus_message_set_destination (DBusMessage* message, const(char)* destination);
const(char)* dbus_message_get_destination (DBusMessage* message);
dbus_bool_t dbus_message_set_sender (DBusMessage* message, const(char)* sender);
const(char)* dbus_message_get_sender (DBusMessage* message);
const(char)* dbus_message_get_signature (DBusMessage* message);
void dbus_message_set_no_reply (DBusMessage* message, dbus_bool_t no_reply);
dbus_bool_t dbus_message_get_no_reply (DBusMessage* message);
dbus_bool_t dbus_message_is_method_call (DBusMessage* message, const(char)* iface, const(char)* method);
dbus_bool_t dbus_message_is_signal (DBusMessage* message, const(char)* iface, const(char)* signal_name);
dbus_bool_t dbus_message_is_error (DBusMessage* message, const(char)* error_name);
dbus_bool_t dbus_message_has_destination (DBusMessage* message, const(char)* bus_name);
dbus_bool_t dbus_message_has_sender (DBusMessage* message, const(char)* unique_bus_name);
dbus_bool_t dbus_message_has_signature (DBusMessage* message, const(char)* signature);
dbus_uint32_t dbus_message_get_serial (DBusMessage* message);
void dbus_message_set_serial (DBusMessage* message, dbus_uint32_t serial);
dbus_bool_t dbus_message_set_reply_serial (DBusMessage* message, dbus_uint32_t reply_serial);
dbus_uint32_t dbus_message_get_reply_serial (DBusMessage* message);
void dbus_message_set_auto_start (DBusMessage* message, dbus_bool_t auto_start);
dbus_bool_t dbus_message_get_auto_start (DBusMessage* message);
dbus_bool_t dbus_message_get_path_decomposed (DBusMessage* message, char*** path);
dbus_bool_t dbus_message_append_args (DBusMessage* message, int first_arg_type, ...);
dbus_bool_t dbus_message_append_args_valist (DBusMessage* message, int first_arg_type, va_list var_args);
dbus_bool_t dbus_message_get_args (DBusMessage* message, DBusError* error, int first_arg_type, ...);
dbus_bool_t dbus_message_get_args_valist (DBusMessage* message, DBusError* error, int first_arg_type, va_list var_args);
dbus_bool_t dbus_message_contains_unix_fds (DBusMessage* message);
dbus_bool_t dbus_message_iter_init (DBusMessage* message, DBusMessageIter* iter);
dbus_bool_t dbus_message_iter_has_next (DBusMessageIter* iter);
dbus_bool_t dbus_message_iter_next (DBusMessageIter* iter);
char* dbus_message_iter_get_signature (DBusMessageIter* iter);
int dbus_message_iter_get_arg_type (DBusMessageIter* iter);
int dbus_message_iter_get_element_type (DBusMessageIter* iter);
void dbus_message_iter_recurse (DBusMessageIter* iter, DBusMessageIter* sub);
void dbus_message_iter_get_basic (DBusMessageIter* iter, void* value);
int dbus_message_iter_get_array_len (DBusMessageIter* iter);
void dbus_message_iter_get_fixed_array (DBusMessageIter* iter, void* value, int* n_elements);
void dbus_message_iter_init_append (DBusMessage* message, DBusMessageIter* iter);
dbus_bool_t dbus_message_iter_append_basic (DBusMessageIter* iter, int type, const(void)* value);
dbus_bool_t dbus_message_iter_append_fixed_array (DBusMessageIter* iter, int element_type, const(void)* value, int n_elements);
dbus_bool_t dbus_message_iter_open_container (DBusMessageIter* iter, int type, const(char)* contained_signature, DBusMessageIter* sub);
dbus_bool_t dbus_message_iter_close_container (DBusMessageIter* iter, DBusMessageIter* sub);
void dbus_message_iter_abandon_container (DBusMessageIter* iter, DBusMessageIter* sub);
void dbus_message_lock (DBusMessage* message);
dbus_bool_t dbus_set_error_from_message (DBusError* error, DBusMessage* message);
dbus_bool_t dbus_message_allocate_data_slot (dbus_int32_t* slot_p);
void dbus_message_free_data_slot (dbus_int32_t* slot_p);
dbus_bool_t dbus_message_set_data (DBusMessage* message, dbus_int32_t slot, void* data, DBusFreeFunction free_data_func);
void* dbus_message_get_data (DBusMessage* message, dbus_int32_t slot);
int dbus_message_type_from_string (const(char)* type_str);
const(char)* dbus_message_type_to_string (int type);
dbus_bool_t dbus_message_marshal (DBusMessage* msg, char** marshalled_data_p, int* len_p);
DBusMessage* dbus_message_demarshal (const(char)* str, int len, DBusError* error);
int dbus_message_demarshal_bytes_needed (const(char)* str, int len);
// END dbus/dbus-message.d
// START dbus/dbus-connection.d
alias uint function (DBusWatch*, void*) DBusAddWatchFunction;
alias void function (DBusWatch*, void*) DBusWatchToggledFunction;
alias void function (DBusWatch*, void*) DBusRemoveWatchFunction;
alias uint function (DBusTimeout*, void*) DBusAddTimeoutFunction;
alias void function (DBusTimeout*, void*) DBusTimeoutToggledFunction;
alias void function (DBusTimeout*, void*) DBusRemoveTimeoutFunction;
alias void function (DBusConnection*, DBusDispatchStatus, void*) DBusDispatchStatusFunction;
alias void function (void*) DBusWakeupMainFunction;
alias uint function (DBusConnection*, c_ulong, void*) DBusAllowUnixUserFunction;
alias uint function (DBusConnection*, const(char)*, void*) DBusAllowWindowsUserFunction;
alias void function (DBusPendingCall*, void*) DBusPendingCallNotifyFunction;
alias DBusHandlerResult function (DBusConnection*, DBusMessage*, void*) DBusHandleMessageFunction;
alias void function (DBusConnection*, void*) DBusObjectPathUnregisterFunction;
alias DBusHandlerResult function (DBusConnection*, DBusMessage*, void*) DBusObjectPathMessageFunction;

enum DBusWatchFlags
{
    DBUS_WATCH_READABLE = 1,
    DBUS_WATCH_WRITABLE = 2,
    DBUS_WATCH_ERROR = 4,
    DBUS_WATCH_HANGUP = 8
}

enum DBusDispatchStatus
{
    DBUS_DISPATCH_DATA_REMAINS = 0,
    DBUS_DISPATCH_COMPLETE = 1,
    DBUS_DISPATCH_NEED_MEMORY = 2
}

struct DBusObjectPathVTable
{
    DBusObjectPathUnregisterFunction unregister_function;
    DBusObjectPathMessageFunction message_function;
    void function (void*) dbus_internal_pad1;
    void function (void*) dbus_internal_pad2;
    void function (void*) dbus_internal_pad3;
    void function (void*) dbus_internal_pad4;
}

struct DBusPreallocatedSend;


struct DBusTimeout;


struct DBusPendingCall;


struct DBusConnection;


struct DBusWatch;


DBusConnection* dbus_connection_open (const(char)* address, DBusError* error);
DBusConnection* dbus_connection_open_private (const(char)* address, DBusError* error);
DBusConnection* dbus_connection_ref (DBusConnection* connection);
void dbus_connection_unref (DBusConnection* connection);
void dbus_connection_close (DBusConnection* connection);
dbus_bool_t dbus_connection_get_is_connected (DBusConnection* connection);
dbus_bool_t dbus_connection_get_is_authenticated (DBusConnection* connection);
dbus_bool_t dbus_connection_get_is_anonymous (DBusConnection* connection);
char* dbus_connection_get_server_id (DBusConnection* connection);
dbus_bool_t dbus_connection_can_send_type (DBusConnection* connection, int type);
void dbus_connection_set_exit_on_disconnect (DBusConnection* connection, dbus_bool_t exit_on_disconnect);
void dbus_connection_flush (DBusConnection* connection);
dbus_bool_t dbus_connection_read_write_dispatch (DBusConnection* connection, int timeout_milliseconds);
dbus_bool_t dbus_connection_read_write (DBusConnection* connection, int timeout_milliseconds);
DBusMessage* dbus_connection_borrow_message (DBusConnection* connection);
void dbus_connection_return_message (DBusConnection* connection, DBusMessage* message);
void dbus_connection_steal_borrowed_message (DBusConnection* connection, DBusMessage* message);
DBusMessage* dbus_connection_pop_message (DBusConnection* connection);
DBusDispatchStatus dbus_connection_get_dispatch_status (DBusConnection* connection);
DBusDispatchStatus dbus_connection_dispatch (DBusConnection* connection);
dbus_bool_t dbus_connection_has_messages_to_send (DBusConnection* connection);
dbus_bool_t dbus_connection_send (DBusConnection* connection, DBusMessage* message, dbus_uint32_t* client_serial);
dbus_bool_t dbus_connection_send_with_reply (DBusConnection* connection, DBusMessage* message, DBusPendingCall** pending_return, int timeout_milliseconds);
DBusMessage* dbus_connection_send_with_reply_and_block (DBusConnection* connection, DBusMessage* message, int timeout_milliseconds, DBusError* error);
dbus_bool_t dbus_connection_set_watch_functions (DBusConnection* connection, DBusAddWatchFunction add_function, DBusRemoveWatchFunction remove_function, DBusWatchToggledFunction toggled_function, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_connection_set_timeout_functions (DBusConnection* connection, DBusAddTimeoutFunction add_function, DBusRemoveTimeoutFunction remove_function, DBusTimeoutToggledFunction toggled_function, void* data, DBusFreeFunction free_data_function);
void dbus_connection_set_wakeup_main_function (DBusConnection* connection, DBusWakeupMainFunction wakeup_main_function, void* data, DBusFreeFunction free_data_function);
void dbus_connection_set_dispatch_status_function (DBusConnection* connection, DBusDispatchStatusFunction function_, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_connection_get_unix_user (DBusConnection* connection, c_ulong* uid);
dbus_bool_t dbus_connection_get_unix_process_id (DBusConnection* connection, c_ulong* pid);
dbus_bool_t dbus_connection_get_adt_audit_session_data (DBusConnection* connection, void** data, dbus_int32_t* data_size);
void dbus_connection_set_unix_user_function (DBusConnection* connection, DBusAllowUnixUserFunction function_, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_connection_get_windows_user (DBusConnection* connection, char** windows_sid_p);
void dbus_connection_set_windows_user_function (DBusConnection* connection, DBusAllowWindowsUserFunction function_, void* data, DBusFreeFunction free_data_function);
void dbus_connection_set_allow_anonymous (DBusConnection* connection, dbus_bool_t value);
void dbus_connection_set_route_peer_messages (DBusConnection* connection, dbus_bool_t value);
dbus_bool_t dbus_connection_add_filter (DBusConnection* connection, DBusHandleMessageFunction function_, void* user_data, DBusFreeFunction free_data_function);
void dbus_connection_remove_filter (DBusConnection* connection, DBusHandleMessageFunction function_, void* user_data);
dbus_bool_t dbus_connection_allocate_data_slot (dbus_int32_t* slot_p);
void dbus_connection_free_data_slot (dbus_int32_t* slot_p);
dbus_bool_t dbus_connection_set_data (DBusConnection* connection, dbus_int32_t slot, void* data, DBusFreeFunction free_data_func);
void* dbus_connection_get_data (DBusConnection* connection, dbus_int32_t slot);
void dbus_connection_set_change_sigpipe (dbus_bool_t will_modify_sigpipe);
void dbus_connection_set_max_message_size (DBusConnection* connection, c_long size);
c_long dbus_connection_get_max_message_size (DBusConnection* connection);
void dbus_connection_set_max_received_size (DBusConnection* connection, c_long size);
c_long dbus_connection_get_max_received_size (DBusConnection* connection);
void dbus_connection_set_max_message_unix_fds (DBusConnection* connection, c_long n);
c_long dbus_connection_get_max_message_unix_fds (DBusConnection* connection);
void dbus_connection_set_max_received_unix_fds (DBusConnection* connection, c_long n);
c_long dbus_connection_get_max_received_unix_fds (DBusConnection* connection);
c_long dbus_connection_get_outgoing_size (DBusConnection* connection);
c_long dbus_connection_get_outgoing_unix_fds (DBusConnection* connection);
DBusPreallocatedSend* dbus_connection_preallocate_send (DBusConnection* connection);
void dbus_connection_free_preallocated_send (DBusConnection* connection, DBusPreallocatedSend* preallocated);
void dbus_connection_send_preallocated (DBusConnection* connection, DBusPreallocatedSend* preallocated, DBusMessage* message, dbus_uint32_t* client_serial);
dbus_bool_t dbus_connection_try_register_object_path (DBusConnection* connection, const(char)* path, const(DBusObjectPathVTable)* vtable, void* user_data, DBusError* error);
dbus_bool_t dbus_connection_register_object_path (DBusConnection* connection, const(char)* path, const(DBusObjectPathVTable)* vtable, void* user_data);
dbus_bool_t dbus_connection_try_register_fallback (DBusConnection* connection, const(char)* path, const(DBusObjectPathVTable)* vtable, void* user_data, DBusError* error);
dbus_bool_t dbus_connection_register_fallback (DBusConnection* connection, const(char)* path, const(DBusObjectPathVTable)* vtable, void* user_data);
dbus_bool_t dbus_connection_unregister_object_path (DBusConnection* connection, const(char)* path);
dbus_bool_t dbus_connection_get_object_path_data (DBusConnection* connection, const(char)* path, void** data_p);
dbus_bool_t dbus_connection_list_registered (DBusConnection* connection, const(char)* parent_path, char*** child_entries);
dbus_bool_t dbus_connection_get_unix_fd (DBusConnection* connection, int* fd);
dbus_bool_t dbus_connection_get_socket (DBusConnection* connection, int* fd);
int dbus_watch_get_fd (DBusWatch* watch);
int dbus_watch_get_unix_fd (DBusWatch* watch);
int dbus_watch_get_socket (DBusWatch* watch);
uint dbus_watch_get_flags (DBusWatch* watch);
void* dbus_watch_get_data (DBusWatch* watch);
void dbus_watch_set_data (DBusWatch* watch, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_watch_handle (DBusWatch* watch, uint flags);
dbus_bool_t dbus_watch_get_enabled (DBusWatch* watch);
int dbus_timeout_get_interval (DBusTimeout* timeout);
void* dbus_timeout_get_data (DBusTimeout* timeout);
void dbus_timeout_set_data (DBusTimeout* timeout, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_timeout_handle (DBusTimeout* timeout);
dbus_bool_t dbus_timeout_get_enabled (DBusTimeout* timeout);
// END dbus/dbus-connection.d
// START dbus/dbus-pending-call.d
DBusPendingCall* dbus_pending_call_ref (DBusPendingCall* pending);
void dbus_pending_call_unref (DBusPendingCall* pending);
dbus_bool_t dbus_pending_call_set_notify (DBusPendingCall* pending, DBusPendingCallNotifyFunction function_, void* user_data, DBusFreeFunction free_user_data);
void dbus_pending_call_cancel (DBusPendingCall* pending);
dbus_bool_t dbus_pending_call_get_completed (DBusPendingCall* pending);
DBusMessage* dbus_pending_call_steal_reply (DBusPendingCall* pending);
void dbus_pending_call_block (DBusPendingCall* pending);
dbus_bool_t dbus_pending_call_allocate_data_slot (dbus_int32_t* slot_p);
void dbus_pending_call_free_data_slot (dbus_int32_t* slot_p);
dbus_bool_t dbus_pending_call_set_data (DBusPendingCall* pending, dbus_int32_t slot, void* data, DBusFreeFunction free_data_func);
void* dbus_pending_call_get_data (DBusPendingCall* pending, dbus_int32_t slot);
// END dbus/dbus-pending-call.d
// START dbus/dbus-server.d
alias void function (DBusServer*, DBusConnection*, void*) DBusNewConnectionFunction;

struct DBusServer;


DBusServer* dbus_server_listen (const(char)* address, DBusError* error);
DBusServer* dbus_server_ref (DBusServer* server);
void dbus_server_unref (DBusServer* server);
void dbus_server_disconnect (DBusServer* server);
dbus_bool_t dbus_server_get_is_connected (DBusServer* server);
char* dbus_server_get_address (DBusServer* server);
char* dbus_server_get_id (DBusServer* server);
void dbus_server_set_new_connection_function (DBusServer* server, DBusNewConnectionFunction function_, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_server_set_watch_functions (DBusServer* server, DBusAddWatchFunction add_function, DBusRemoveWatchFunction remove_function, DBusWatchToggledFunction toggled_function, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_server_set_timeout_functions (DBusServer* server, DBusAddTimeoutFunction add_function, DBusRemoveTimeoutFunction remove_function, DBusTimeoutToggledFunction toggled_function, void* data, DBusFreeFunction free_data_function);
dbus_bool_t dbus_server_set_auth_mechanisms (DBusServer* server, const(char*)* mechanisms);
dbus_bool_t dbus_server_allocate_data_slot (dbus_int32_t* slot_p);
void dbus_server_free_data_slot (dbus_int32_t* slot_p);
dbus_bool_t dbus_server_set_data (DBusServer* server, int slot, void* data, DBusFreeFunction free_data_func);
void* dbus_server_get_data (DBusServer* server, int slot);
// END dbus/dbus-server.d
// START dbus/dbus-bus.d
DBusConnection* dbus_bus_get (DBusBusType type, DBusError* error);
DBusConnection* dbus_bus_get_private (DBusBusType type, DBusError* error);
dbus_bool_t dbus_bus_register (DBusConnection* connection, DBusError* error);
dbus_bool_t dbus_bus_set_unique_name (DBusConnection* connection, const(char)* unique_name);
const(char)* dbus_bus_get_unique_name (DBusConnection* connection);
c_ulong dbus_bus_get_unix_user (DBusConnection* connection, const(char)* name, DBusError* error);
char* dbus_bus_get_id (DBusConnection* connection, DBusError* error);
int dbus_bus_request_name (DBusConnection* connection, const(char)* name, uint flags, DBusError* error);
int dbus_bus_release_name (DBusConnection* connection, const(char)* name, DBusError* error);
dbus_bool_t dbus_bus_name_has_owner (DBusConnection* connection, const(char)* name, DBusError* error);
dbus_bool_t dbus_bus_start_service_by_name (DBusConnection* connection, const(char)* name, dbus_uint32_t flags, dbus_uint32_t* reply, DBusError* error);
void dbus_bus_add_match (DBusConnection* connection, const(char)* rule, DBusError* error);
void dbus_bus_remove_match (DBusConnection* connection, const(char)* rule, DBusError* error);
// END dbus/dbus-bus.d
// START dbus/dbus.d

// END dbus/dbus.d
