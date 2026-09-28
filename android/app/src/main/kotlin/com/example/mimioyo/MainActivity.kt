package com.example.mimioyo

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.opengl.GLES20
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import javax.microedition.khronos.egl.EGL10
import javax.microedition.khronos.egl.EGLConfig

class MainActivity : FlutterActivity() {
    private val channel = "mimioyo/hardware"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "info" -> result.success(obtenerInfo())
                    else -> result.notImplemented()
                }
            }
    }

    private fun obtenerInfo(): Map<String, Any> {
        val info = HashMap<String, Any>()

        info["modelo"] = Build.MODEL ?: "?"
        info["fabricante"] = Build.MANUFACTURER ?: "?"
        info["android"] = "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})"

        val mi = ActivityManager.MemoryInfo()
        (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(mi)
        info["ramTotalGb"] = mi.totalMem.toDouble() / 1024.0 / 1024.0 / 1024.0
        info["ramLibreGb"] = mi.availMem.toDouble() / 1024.0 / 1024.0 / 1024.0
        info["ramBajo"] = mi.lowMemory

        val st = StatFs(filesDir.absolutePath)
        info["almacenTotalGb"] = st.totalBytes.toDouble() / 1024.0 / 1024.0 / 1024.0
        info["almacenLibreGb"] = st.availableBytes.toDouble() / 1024.0 / 1024.0 / 1024.0

        info.putAll(gpuInfo())

        return info
    }

    /** Vulkan pedido por el sistema: 0 = ninguno, 1 = level 0, 2 = level 1. */
    private fun nivelVulkan(pm: PackageManager): Int = if (
        Build.VERSION.SDK_INT >= 24 &&
        pm.hasSystemFeature(PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL)
    ) {
        val f = pm.systemAvailableFeatures.firstOrNull {
            it.name == PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL
        }
        if (f != null && f.version > 0) f.version else 0
    } else {
        0
    }

    /** Vulkan que anuncia el driver (flags, p.ej. 0x00400000). */
    private fun versionVulkan(pm: PackageManager): Int = if (
        Build.VERSION.SDK_INT >= 24
    ) {
        val f = pm.systemAvailableFeatures.firstOrNull {
            it.name == PackageManager.FEATURE_VULKAN_HARDWARE_VERSION
        }
        f?.version ?: 0
    } else {
        0
    }

    /** OpenGL ES requerido por la app, como 3.2 (de 0x00030002). */
    private fun reqGlEs(): String = try {
        val raw = applicationInfo.reqGlEsVersion
        val major = (raw shr 16) and 0xff
        val minor = (raw shr 8) and 0xff
        if (major == 0) "?" else "$major.$minor"
    } catch (_: Throwable) {
        "?"
    }

    /** GL/Vulkan leídos de verdad: renderer por EGL + features del sistema. */
    private fun gpuInfo(): Map<String, Any> {
        val m = HashMap<String, Any>()
        val pm = packageManager

        m["vulkanNivel"] = nivelVulkan(pm)
        m["vulkanVersion"] = versionVulkan(pm)
        m["openGLEsReq"] = reqGlEs()

        var renderer = "?"
        var vendor = "?"
        var version = "?"
        var glEs = "?"
        var error: String? = null
        try {
            val egl = javax.microedition.khronos.egl.EGLContext.getEGL()
                as javax.microedition.khronos.egl.EGL10
            val dpy = egl.eglGetDisplay(EGL10.EGL_DEFAULT_DISPLAY)
            val ver = IntArray(2)
            egl.eglInitialize(dpy, ver)

            val cfgs = arrayOfNulls<EGLConfig>(1)
            val n = IntArray(1)
            egl.eglChooseConfig(
                dpy,
                intArrayOf(EGL10.EGL_RENDERABLE_TYPE, 0x0004, EGL10.EGL_NONE),
                cfgs, 1, n
            )
            val cfg = cfgs[0]
            val ctx = egl.eglCreateContext(
                dpy, cfg, EGL10.EGL_NO_CONTEXT,
                intArrayOf(0x3098, 2, EGL10.EGL_NONE)
            )
            val surf = egl.eglCreatePbufferSurface(
                dpy, cfg,
                intArrayOf(
                    EGL10.EGL_WIDTH, 1, EGL10.EGL_HEIGHT, 1, EGL10.EGL_NONE
                )
            )
            egl.eglMakeCurrent(dpy, surf, surf, ctx)

            renderer = GLES20.glGetString(GLES20.GL_RENDERER) ?: "?"
            vendor = GLES20.glGetString(GLES20.GL_VENDOR) ?: "?"
            version = GLES20.glGetString(GLES20.GL_VERSION) ?: "?"
            glEs = version

            egl.eglMakeCurrent(
                dpy, EGL10.EGL_NO_SURFACE, EGL10.EGL_NO_SURFACE,
                EGL10.EGL_NO_CONTEXT
            )
            egl.eglDestroySurface(dpy, surf)
            egl.eglDestroyContext(dpy, ctx)
        } catch (e: Throwable) {
            error = e.message ?: e.javaClass.simpleName
        }

        m["gpuRenderer"] = renderer
        m["gpuVendor"] = vendor
        m["gpuVersion"] = version
        m["openGL"] = glEs
        m["gpuError"] = error ?: ""
        m["impeller"] = true
        m["flutterGpu"] = true
        return m
    }
}
