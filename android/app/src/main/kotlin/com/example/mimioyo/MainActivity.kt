package com.example.mimioyo

import android.app.ActivityManager
import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Build
import android.os.StatFs
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

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

        val st = StatFs(filesDir.absolutePath)
        info["almacenTotalGb"] = st.totalBytes.toDouble() / 1024.0 / 1024.0 / 1024.0
        info["almacenLibreGb"] = st.availableBytes.toDouble() / 1024.0 / 1024.0 / 1024.0

        val (renderer, vendor, version, vulkan, glEs) = obtenerGpuInfo()
        info["gpuRenderer"] = renderer
        info["gpuVendor"] = vendor
        info["gpuVersion"] = version
        info["vulkan"] = vulkan
        info["openGL"] = glEs

        return info
    }

    private fun obtenerGpuInfo(): Quintuple<String, String, String, Boolean, String> {
        var renderer = "?"
        var vendor = "?"
        var version = "?"
        var glEs = "?"

        try {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val display = windowManager.defaultDisplay
            val metrics = DisplayMetrics()
            display.getRealMetrics(metrics)

            val egl = javax.microedition.khronos.egl.EGLContext.getEGL() as javax.microedition.khronos.egl.EGL10
            val displayEgl = egl.eglGetDisplay(javax.microedition.khronos.egl.EGL10.EGL_DEFAULT_DISPLAY)
            val versionEgl = IntArray(2)
            egl.eglInitialize(displayEgl, versionEgl)

            val configs = arrayOfNulls<javax.microedition.khronos.egl.EGLConfig>(1)
            val numConfigs = IntArray(1)
            val attribList = intArrayOf(
                javax.microedition.khronos.egl.EGL10.EGL_RENDERABLE_TYPE,
                0x0004,
                javax.microedition.khronos.egl.EGL10.EGL_NONE
            )
            egl.eglChooseConfig(displayEgl, attribList, configs, 1, numConfigs)

            val contextAttribs = intArrayOf(
                0x3098,
                2,
                javax.microedition.khronos.egl.EGL10.EGL_NONE
            )
            val context = egl.eglCreateContext(displayEgl, configs[0], javax.microedition.khronos.egl.EGL10.EGL_NO_CONTEXT, contextAttribs)

            val surfaceAttribs = intArrayOf(
                javax.microedition.khronos.egl.EGL10.EGL_WIDTH, 1,
                javax.microedition.khronos.egl.EGL10.EGL_HEIGHT, 1,
                javax.microedition.khronos.egl.EGL10.EGL_NONE
            )
            val surface = egl.eglCreatePbufferSurface(displayEgl, configs[0], surfaceAttribs)
            egl.eglMakeCurrent(displayEgl, surface, surface, context)

            renderer = GLES20.glGetString(GLES20.GL_RENDERER) ?: "?"
            vendor = GLES20.glGetString(GLES20.GL_VENDOR) ?: "?"
            version = GLES20.glGetString(GLES20.GL_VERSION) ?: "?"
            glEs = GLES20.glGetString(GLES20.GL_VERSION) ?: "?"

            egl.eglMakeCurrent(displayEgl, javax.microedition.khronos.egl.EGL10.EGL_NO_SURFACE, javax.microedition.khronos.egl.EGL10.EGL_NO_SURFACE, javax.microedition.khronos.egl.EGL10.EGL_NO_CONTEXT)
            egl.eglDestroySurface(displayEgl, surface)
            egl.eglDestroyContext(displayEgl, context)
        } catch (e: Exception) {
            renderer = "Error: ${e.message}"
        }

        val vulkan = android.os.Build.VERSION.SDK_INT >= 24

        return Quintuple(renderer, vendor, version, vulkan, glEs)
    }
}

data class Quintuple<A, B, C, D, E>(val first: A, val second: B, val third: C, val fourth: D, val fifth: E)
