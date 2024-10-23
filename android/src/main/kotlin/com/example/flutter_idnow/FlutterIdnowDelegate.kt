package com.example.flutter_idnow

import android.app.Activity
import android.content.Intent
import android.util.Log
import de.idnow.sdk.IDnowSDK
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class FlutterIdnowDelegate(private val activity: Activity) : PluginRegistry.ActivityResultListener {
    private var result: MethodChannel.Result? = null

    companion object {
        private const val TAG = "MyActivity"
    }

    fun start(call: MethodCall, result: MethodChannel.Result) {
        val providerId: String? = call.argument("providerId")
        try {
            this.result = result
            IDnowSDK.setTransactionToken(providerId)
            IDnowSDK.getInstance().start(IDnowSDK.getTransactionToken())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun setShowVideoOverviewCheck(call: MethodCall, result: MethodChannel.Result) {
        try {
            val flag: Boolean? = call.argument("setShowVideoFlag")
            IDnowSDK.setShowVideoOverviewCheck(flag ?: false, this.activity)
            println(flag)
            result.success(true)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == IDnowSDK.REQUEST_ID_NOW_SDK) {
            when (resultCode) {
                IDnowSDK.RESULT_CODE_SUCCESS -> {
                    data?.let {
                        val transactionToken = it.getStringExtra(IDnowSDK.RESULT_DATA_TRANSACTION_TOKEN)
                        Log.v(TAG, "success, transaction token: $transactionToken")
                        result?.success("success")
                        result = null
                        return true
                    }
                }
                IDnowSDK.RESULT_CODE_CANCEL -> {
                    data?.let {
                        val transactionToken = it.getStringExtra(IDnowSDK.RESULT_DATA_TRANSACTION_TOKEN)
                        val errorMessage = it.getStringExtra(IDnowSDK.RESULT_DATA_ERROR)
                        Log.v(TAG, "canceled, transaction token: $transactionToken, error: $errorMessage")
                        result?.success(errorMessage)
                        result = null
                        return true
                    }
                }
                IDnowSDK.RESULT_CODE_FAILED -> {
                    data?.let {
                        val transactionToken = it.getStringExtra(IDnowSDK.RESULT_DATA_TRANSACTION_TOKEN)
                        val errorMessage = it.getStringExtra(IDnowSDK.RESULT_DATA_ERROR)
                        Log.v(TAG, "failed, transaction token: $transactionToken, error: $errorMessage")
                        result?.success(errorMessage)
                        result = null
                        return true
                    }
                }
                else -> {
                    result?.success(resultCode)
                    result = null
                    Log.v(TAG, "Result Code: $resultCode")
                    return true
                }
            }
        }
        return false
    }
}
