package my.trilobyte.android_shared_storage_writer

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.net.URLConnection
import java.util.*

/** AndroidSharedStorageWriterPlugin */
class AndroidSharedStorageWriterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context : Context

  private lateinit var activity : Activity

  private lateinit var result : Result



  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "android_shared_storage_writer")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    this.result = result
    when (call.method) {
      "api_level" ->
        result.success(Build.VERSION.SDK_INT)
      "write_permission" ->
        result.success(hasWritePermission())
      "request_write_permission" -> {
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 0)
        result.success(null)
      }
      "write" -> {
        val directory: String = call.argument("directory")!!
        val subDirectory: String? = call.argument<String?>("collection")?.trim()
        val filename: String = call.argument("filename")!!
        val data: ByteArray = call.argument("data")!!
        val overwriteExisting: Boolean = call.argument("overwrite_existing")!!

        val resolver = context.contentResolver

        val environmentDirectory = when (directory.toLowerCase(Locale.ROOT)) {
          "pictures" -> Environment.DIRECTORY_PICTURES
          "music" -> Environment.DIRECTORY_MUSIC
          "movies" -> Environment.DIRECTORY_MOVIES
          "alarms" -> Environment.DIRECTORY_ALARMS
          "dcim" -> Environment.DIRECTORY_DCIM
          "downloads" -> Environment.DIRECTORY_DOWNLOADS
          "notifications" -> Environment.DIRECTORY_NOTIFICATIONS
          "podcasts" -> Environment.DIRECTORY_PODCASTS
          "ringtones" -> Environment.DIRECTORY_RINGTONES
          "documents" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) Environment.DIRECTORY_DOCUMENTS else {
            result.error(ErrorCode.InvalidCollection.code, "This version of Android does not support this Shared Storage Location.", null)
            return
          }
          "screenshots" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) Environment.DIRECTORY_SCREENSHOTS else {
            result.error(ErrorCode.InvalidCollection.code, "This version of Android does not support this Shared Storage Location.", null)
            return
          }
          else -> {
            result.error(ErrorCode.InvalidCollection.code, "Unexpected Shared Storage Location type.", null)
            return
          }
        }
        val mimeType = URLConnection.guessContentTypeFromStream(data.inputStream())
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)!!
        val baseType = mimeType.split('/').first()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          val getContentUri = when (baseType) {
            "image" -> MediaStore.Images.Media::getContentUri
            "video" -> MediaStore.Video.Media::getContentUri
            "audio" -> MediaStore.Audio.Media::getContentUri
            else -> MediaStore.Files::getContentUri
          }
          val collection = getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
          val relPath = if (!subDirectory.isNullOrBlank()) "$environmentDirectory${File.separator}$subDirectory" else environmentDirectory
          val details = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, relPath)
          }
          val projection = arrayOf(
                  MediaStore.Images.Media._ID,
                  MediaStore.Images.Media.DISPLAY_NAME,
                  MediaStore.Images.Media.RELATIVE_PATH
          )
          val resultsCursor = resolver.query(collection, projection, null, null, null)
          var uri: Uri? = null
          while (resultsCursor!!.moveToNext()) {
            val existingName = resultsCursor.getString(resultsCursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME))
            val existingPath = resultsCursor.getString(resultsCursor.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH))
            val parts = existingName.split('.')
            val displayName = if (parts.count() > 1) parts.subList(0, parts.count() - 1).joinToString(".") else parts.first()
            if (existingPath == "$relPath${File.separator}" && displayName == filename) {
              uri = ContentUris.withAppendedId(collection, resultsCursor.getLong(resultsCursor.getColumnIndex(MediaStore.Images.Media._ID)))
              break
            }
          }
          resultsCursor.close()
          if (uri == null) {
            try {
              uri = resolver.insert(collection, details)
            } catch (e: IllegalArgumentException) {
              result.error(ErrorCode.ContentNotAllowed.code, e.message, null)
              return
            }
          } else if (!overwriteExisting) {
            result.error(ErrorCode.FileExists.code, "Cannot overwrite existing file.", null)
            return
          }
          val stream = resolver.openOutputStream(uri!!, "w")!!
          stream.write(data)
          stream.close()
          result.success(uri.path)
        } else {
          if (!hasWritePermission()) {
            result.error(ErrorCode.WritePermissionRequired.code, "Storage Write Permissions Required", null)
          } else {
            val file = legacyWrite(data, environmentDirectory, filename, extension, subDirectory, overwriteExisting)
            if (file == null) {
              result.error(ErrorCode.FileExists.code, "Cannot overwrite existing file.", null)
            } else {
              activity.sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(file)))
              result.success(file.path)
            }
          }
        }
      }
      else ->
        result.notImplemented()
    }
  }

  private fun hasWritePermission() : Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q || ContextCompat.checkSelfPermission(context,  Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
  }

  private fun legacyWrite(data: ByteArray, environmentDirectory: String, filename: String, extension: String, subDirectory: String?,  overwriteExisting: Boolean = false) : File? {
    val baseDirectory = Environment.getExternalStoragePublicDirectory(environmentDirectory)
    val collection = if (!subDirectory.isNullOrBlank()) File(baseDirectory, subDirectory) else baseDirectory
    if (!collection.exists()) {
      collection.mkdirs()
    }
    val file = File(collection, "$filename.$extension")
    if (!file.exists()) {
      file.createNewFile()
    } else {
      if (!overwriteExisting) {
        return null
      }
    }
    file.writeBytes(data)
    return file
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

  override fun onDetachedFromActivity() {}
}
