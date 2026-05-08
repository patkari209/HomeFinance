package com.durgeshpatkari.homefinanceplanner

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object SmsBridgeStore {
    private const val prefsName = "home_finance_sms_bridge"
    private const val queueKey = "pending_sms_queue"

    fun enqueueMessage(
        context: Context,
        messageId: String,
        sender: String,
        body: String,
        timestamp: Long,
    ) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val current = JSONArray(prefs.getString(queueKey, "[]") ?: "[]")
        val item = JSONObject()
            .put("messageId", messageId)
            .put("sender", sender)
            .put("body", body)
            .put("timestamp", timestamp)
        current.put(item)
        prefs.edit().putString(queueKey, current.toString()).apply()
    }

    fun consumePendingMessages(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val current = JSONArray(prefs.getString(queueKey, "[]") ?: "[]")
        val items = mutableListOf<Map<String, Any>>()
        for (index in 0 until current.length()) {
            val item = current.optJSONObject(index) ?: continue
            items.add(
                mapOf(
                    "messageId" to item.optString("messageId"),
                    "sender" to item.optString("sender"),
                    "body" to item.optString("body"),
                    "timestamp" to item.optLong("timestamp"),
                )
            )
        }
        prefs.edit().remove(queueKey).apply()
        return items
    }
}
