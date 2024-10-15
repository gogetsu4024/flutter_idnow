package com.example.flutter_idnow

import android.app.Activity
import de.idnow.sdk.IDnowSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class FlutterIdnowPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private var channel: MethodChannel? = null
  private var delegate: FlutterIdnowDelegate? = null
  private var activityPluginBinding: ActivityPluginBinding? = null


  private fun setupActivity(activity: Activity): FlutterIdnowDelegate {
    delegate = FlutterIdnowDelegate(activity)
    return delegate!!
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_idnow")
    channel?.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityPluginBinding = binding
    setupActivity(binding.activity)
    binding.addActivityResultListener(delegate!!)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    activityPluginBinding?.removeActivityResultListener(delegate!!)
    activityPluginBinding = null
    delegate = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method == "startIdentification") {
      val providerCompanyId = call.argument<String>("providerCompanyId")
      try {
        providerCompanyId?.let {
          IDnowSDK.getInstance().initialize(activityPluginBinding?.activity!!, it)
          delegate?.start(call, result)
        }
      } catch (e: Exception) {
        e.printStackTrace()
      }
    } else {
      result.notImplemented()
    }
  }
}