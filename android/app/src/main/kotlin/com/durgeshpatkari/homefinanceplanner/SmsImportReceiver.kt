package com.durgeshpatkari.homefinanceplanner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsImportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        for (message in Telephony.Sms.Intents.getMessagesFromIntent(intent)) {
            val body = message.messageBody ?: continue
            val sender = message.originatingAddress ?: ""
            val timestamp = message.timestampMillis
            val messageId = "${timestamp}_${sender.hashCode()}_${body.hashCode()}"

            val payload = mapOf(
                "messageId" to messageId,
                "sender" to sender,
                "body" to body,
                "timestamp" to timestamp,
            )

            SmsBridgeStore.enqueueMessage(
                context = context,
                messageId = messageId,
                sender = sender,
                body = body,
                timestamp = timestamp,
            )
            MainActivity.pushSmsEvent(payload)
        }
    }
}
