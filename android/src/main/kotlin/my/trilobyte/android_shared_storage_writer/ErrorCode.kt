package my.trilobyte.android_shared_storage_writer

enum class ErrorCode(val code: String) {
    ContentNotAllowed("content_not_allowed"),
    FileExists("file_exists"),
    InvalidCollection("invalid_collection"),
    WritePermissionRequired("write_permission_required")
}