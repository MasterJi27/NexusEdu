package com.nexus.edu

import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Debug
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.security.MessageDigest

object SecurityChannel {
    private const val CHANNEL = "com.nexus.edu/security"

    fun register(engine: FlutterEngine, activity: MainActivity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "runChecks" -> result.success(runChecks(activity))
                    "computeTextHash" -> result.success(computeTextHash(activity))
                    "watermarkHash" -> {
                        val input = (call.arguments as? Map<*, *>)?.get("input") as? String ?: ""
                        result.success(watermarkHash(input))
                    }
                    "isEmulator" -> result.success(if (isEmulator()) "true" else "false")
                    "getPackageInfo" -> result.success(getPackageInfo(activity))
                    "onTamper" -> {
                        val reason = (call.arguments as? Map<*, *>)?.get("reason")?.toString() ?: "unknown"
                        onTamper(activity, reason)
                        result.success(null)
                    }
                    "registerScreenCaptureCallback" -> registerScreenCaptureCallback(activity, engine, result)
                    "unregisterScreenCaptureCallback" -> {
                        unregisterScreenCaptureCallback(activity)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("sec_err", e.message, null)
            }
        }
    }

    private fun watermarkHash(input: String): String {
        // FNV-1a 32-bit -> 8 hex, mirrors C++ nx_watermark_hash for forensic watermark
        var h = 2166136261u
        for (b in input.toByteArray(Charsets.UTF_8)) {
            h = h xor (b.toUInt())
            h *= 16777619u
        }
        h = h xor input.length.toUInt()
        h *= 16777619u
        return "%08x".format(h.toLong() and 0xFFFFFFFFL)
    }

    private fun runChecks(activity: MainActivity): String {
        val v = mutableListOf<String>()
        if (isDebuggable(activity)) v.add("debuggable_flag")
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) v.add("debugger_connected")
        if (hasTracerPid()) v.add("tracer_pid")
        if (isFridaPresent()) v.add("frida")
        if (isXposedPresent()) v.add("xposed")
        if (isRooted()) v.add("rooted")
        // Note: emulator check already separate; include here too if wanted
        if (v.isEmpty()) return "ok"
        return v.joinToString(",")
    }

    private fun isDebuggable(activity: MainActivity): Boolean {
        return (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    private fun hasTracerPid(): Boolean {
        return try {
            val status = File("/proc/self/status").readText()
            status.lines().any { it.startsWith("TracerPid:") && it.split(":").getOrNull(1)?.trim() != "0" }
        } catch (_: Exception) { false }
    }

    private fun isFridaPresent(): Boolean {
        // Files
        val suspects = listOf(
            "/data/local/tmp/re.frida.server",
            "/data/local/tmp/frida",
            "/system/lib/libfrida-gadget.so",
            "/system/lib64/libfrida-gadget.so"
        )
        if (suspects.any { File(it).exists() }) return true
        // Maps
        try {
            val maps = File("/proc/self/maps").readText()
            if (maps.contains("frida") || maps.contains("gadget")) return true
        } catch (_: Exception) {}
        // Port 27042
        try {
            java.net.Socket().use { s -> s.connect(java.net.InetSocketAddress("127.0.0.1", 27042), 400); return true }
        } catch (_: Exception) {}
        // Prop
        try {
            val p = Runtime.getRuntime().exec(arrayOf("getprop", "ro.frida.version")).inputStream.bufferedReader().readText()
            if (p.isNotBlank()) return true
        } catch (_: Exception) {}
        return false
    }

    private fun isXposedPresent(): Boolean {
        try {
            val maps = File("/proc/self/maps").readText()
            if (maps.contains("xposed") || maps.contains("substrate")) return true
        } catch (_: Exception) {}
        try {
            // Check for Xposed class
            Class.forName("de.robv.android.xposed.XposedBridge")
            return true
        } catch (_: Exception) {}
        val xposedFiles = listOf("/system/framework/XposedBridge.jar", "/system/lib/libxposed_art.so")
        if (xposedFiles.any { File(it).exists() }) return true
        return false
    }

    private fun isRooted(): Boolean {
        val suPaths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/system/su", "/data/local/su", "/data/local/xbin/su",
            "/system/app/Superuser.apk", "/system/app/SuperSu.apk"
        )
        if (suPaths.any { File(it).exists() }) return true
        // test-keys
        if (Build.TAGS?.contains("test-keys") == true) return true
        // which su
        try {
            val proc = Runtime.getRuntime().exec(arrayOf("which", "su"))
            if (proc.inputStream.bufferedReader().readText().isNotBlank()) return true
        } catch (_: Exception) {}
        return false
    }

    private fun isEmulator(): Boolean {
        val fp = Build.FINGERPRINT
        val model = Build.MODEL
        val manu = Build.MANUFACTURER
        val product = Build.PRODUCT
        val hardware = Build.HARDWARE
        return (
            fp.startsWith("generic") || fp.contains("unknown") ||
            model.contains("google_sdk") || model.contains("Emulator") || model.contains("Android SDK built for") ||
            manu.contains("Genymotion") || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
            product == "google_sdk" || product == "sdk" || hardware.contains("goldfish") || hardware.contains("ranchu") ||
            Build.PRODUCT.contains("vbox86p") || Build.PRODUCT.contains("emulator")
        )
    }

    private var screenCaptureCallback: Any? = null

    private fun registerScreenCaptureCallback(activity: MainActivity, engine: FlutterEngine, result: MethodChannel.Result) {
        // Use reflection to avoid compile-time dependency on API 34 ScreenCaptureCallback
        // Fallback: rely on FLAG_SECURE + forensic watermark for second-camera deterrence
        try {
            if (Build.VERSION.SDK_INT < 34) { result.success(false); return }
            val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            val exec = activity.mainExecutor
            val clazz = Class.forName("android.window.ScreenCaptureCallback")
            val cb = java.lang.reflect.Proxy.newProxyInstance(
                clazz.classLoader, arrayOf(clazz)
            ) { _, _, _ ->
                try { ch.invokeMethod("onScreenCaptured", null) } catch (_: Exception) {}
                android.util.Log.w("NexusSecurity", "screen_capture_detected")
                null
            }
            val m = activity.javaClass.getMethod("registerScreenCaptureCallback", java.util.concurrent.Executor::class.java, clazz)
            m.invoke(activity, exec, cb)
            screenCaptureCallback = cb
            result.success(true)
        } catch (e: Exception) {
            // Reflection failed — fallback to watermark only
            result.success(false)
        }
    }

    private fun unregisterScreenCaptureCallback(activity: MainActivity) {
        try {
            val cb = screenCaptureCallback ?: return
            if (Build.VERSION.SDK_INT < 34) return
            val clazz = Class.forName("android.window.ScreenCaptureCallback")
            val m = activity.javaClass.getMethod("unregisterScreenCaptureCallback", clazz)
            m.invoke(activity, cb)
            screenCaptureCallback = null
        } catch (_: Exception) {}
    }

    private fun getPackageInfo(activity: MainActivity): Map<String, String> {
        return try {
            val pm = activity.packageManager
            val pkg = activity.packageName
            val info = pm.getPackageInfo(pkg, 0)
            mapOf("package" to pkg, "version" to (info.versionName ?: "1.2.6"), "code" to "${info.longVersionCode}")
        } catch (_: Exception) {
            mapOf("package" to "com.nexus.edu", "version" to "1.2.6")
        }
    }

    private fun onTamper(activity: MainActivity, reason: String) {
        android.util.Log.w("NexusSecurity", "tamper:$reason")
        // Wipe sensitive prefs (FlutterSecureStorage is encrypted, but also clear SharedPreferences that may contain fallback)
        try {
            val prefs = activity.getSharedPreferences("FlutterSecureStorage", android.content.Context.MODE_PRIVATE)
            prefs.edit().clear().apply()
        } catch (_: Exception) {}
        // Optionally kill process after short delay — caller in Dart also exits
    }

    // ---- .text hash ----

    private fun computeTextHash(activity: MainActivity): String {
        return try {
            val libPath = findLibApp(activity) ?: return fallbackHash(activity)
            val hash = hashTextSegment(libPath) ?: return fallbackHash(activity)
            hash
        } catch (e: Exception) {
            android.util.Log.w("NexusSecurity", "computeTextHash fail ${e.message}")
            fallbackHash(activity)
        }
    }

    private fun findLibApp(activity: MainActivity): String? {
        // Try nativeLibraryDir first
        val dir = activity.applicationInfo.nativeLibraryDir
        val candidates = listOf(
            "$dir/libapp.so",
            "$dir/libflutter.so",
            // From maps
        )
        for (c in candidates) if (File(c).exists()) return c
        // Parse maps
        try {
            val maps = File("/proc/self/maps").readText()
            for (line in maps.lines()) {
                if (line.contains("libapp.so") || line.contains("libflutter.so")) {
                    val path = line.substringAfterLast(" ").trim()
                    if (File(path).exists()) return path
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun fallbackHash(activity: MainActivity): String {
        val info = getPackageInfo(activity)
        val seed = "${info["package"]}|${info["version"]}"
        return sha256(seed.toByteArray(Charsets.UTF_8))
    }

    private fun hashTextSegment(elfPath: String): String? {
        // Minimal ELF parser: find .text via section headers (ELF64 + ELF32)
        RandomAccessFile(elfPath, "r").use { raf ->
            raf.seek(0)
            val magic = ByteArray(4); raf.readFully(magic)
            if (magic[0] != 0x7F.toByte() || magic[1] != 'E'.code.toByte() || magic[2] != 'L'.code.toByte() || magic[3] != 'F'.code.toByte()) return null
            raf.seek(4)
            val eiClass = raf.readUnsignedByte() // 1=32, 2=64
            val eiData = raf.readUnsignedByte() // 1=LE, 2=BE
            val is64 = eiClass == 2
            val le = eiData == 1
            // Helper to read u16/u32/u64
            fun readU16(): Int {
                val b = ByteArray(2); raf.readFully(b)
                return if (le) ((b[1].toInt() and 0xFF) shl 8) or (b[0].toInt() and 0xFF) else ((b[0].toInt() and 0xFF) shl 8) or (b[1].toInt() and 0xFF)
            }
            fun readU32(): Long {
                val b = ByteArray(4); raf.readFully(b)
                return if (le) {
                    ((b[3].toLong() and 0xFF) shl 24) or ((b[2].toLong() and 0xFF) shl 16) or ((b[1].toLong() and 0xFF) shl 8) or (b[0].toLong() and 0xFF)
                } else {
                    ((b[0].toLong() and 0xFF) shl 24) or ((b[1].toLong() and 0xFF) shl 16) or ((b[2].toLong() and 0xFF) shl 8) or (b[0].toLong() and 0xFF)
                }
            }
            fun readU64(): Long {
                val b = ByteArray(8); raf.readFully(b)
                return if (le) {
                    var v = 0L
                    for (i in 7 downTo 0) v = (v shl 8) or (b[i].toLong() and 0xFF)
                    v
                } else {
                    var v = 0L
                    for (i in 0..7) v = (v shl 8) or (b[i].toLong() and 0xFF)
                    v
                }
            }
            // Skip e_version etc to reach header fields — easier: seek to known offsets
            if (is64) {
                // ELF64: e_shoff at 32, e_shentsize 58, e_shnum 60, e_shstrndx 62
                raf.seek(32)
                val shOff = readU64()
                raf.seek(58)
                val shEntSize = readU16()
                val shNum = readU16()
                val shStrNdx = readU16()
                if (shOff == 0L || shNum == 0) return null
                // Read section header string table offset
                raf.seek(shOff + shStrNdx * shEntSize + 24) // sh_offset for ELF64 is at 24
                val strTabOff = readU64()
                // Scan all sections for ".text"
                for (i in 0 until shNum) {
                    raf.seek(shOff + i * shEntSize)
                    val shName = readU32()
                    val shType = readU32()
                    readU64() // flags
                    readU64() // addr
                    val shOffset = readU64()
                    val shSize = readU64()
                    // read name from strtab
                    val namePos = strTabOff + shName
                    raf.seek(namePos)
                    val nameBytes = mutableListOf<Byte>()
                    while (true) {
                        val b = raf.readByte()
                        if (b == 0.toByte()) break
                        nameBytes.add(b)
                    }
                    val name = String(nameBytes.toByteArray(), Charsets.UTF_8)
                    if (name == ".text") {
                        raf.seek(shOffset)
                        val textBytes = ByteArray(shSize.toInt())
                        raf.readFully(textBytes)
                        return sha256(textBytes)
                    }
                }
            } else {
                // ELF32: e_shoff 32, e_shentsize 46, e_shnum 48, e_shstrndx 50
                raf.seek(32)
                val shOff = readU32()
                raf.seek(46)
                val shEntSize = readU16()
                val shNum = readU16()
                val shStrNdx = readU16()
                if (shOff == 0L || shNum == 0) return null
                raf.seek(shOff + shStrNdx * shEntSize + 16)
                val strTabOff = readU32()
                for (i in 0 until shNum) {
                    raf.seek(shOff + i * shEntSize)
                    val shName = readU32()
                    readU32() // type
                    readU32() // flags
                    readU32() // addr
                    val shOffset = readU32()
                    val shSize = readU32()
                    val namePos = strTabOff + shName
                    raf.seek(namePos)
                    val nameBytes = mutableListOf<Byte>()
                    while (true) {
                        val b = raf.readByte()
                        if (b == 0.toByte()) break
                        nameBytes.add(b)
                    }
                    val name = String(nameBytes.toByteArray(), Charsets.UTF_8)
                    if (name == ".text") {
                        raf.seek(shOffset)
                        val textBytes = ByteArray(shSize.toInt())
                        raf.readFully(textBytes)
                        return sha256(textBytes)
                    }
                }
            }
        }
        return null
    }

    private fun sha256(bytes: ByteArray): String {
        val md = MessageDigest.getInstance("SHA-256")
        return md.digest(bytes).joinToString("") { "%02x".format(it) }
    }
}
