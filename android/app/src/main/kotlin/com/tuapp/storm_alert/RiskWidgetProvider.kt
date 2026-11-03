package com.tuapp.storm_alert

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class RiskWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val colors = intArrayOf(
            Color.parseColor("#64708A"), // sin riesgo
            Color.parseColor("#EBD95C"), // bajo
            Color.parseColor("#F5A524"), // moderado
            Color.parseColor("#E5483D"), // alto
            Color.parseColor("#A63CC9")  // extremo
        )
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_risk)
            v.setOnClickPendingIntent(
                R.id.risk_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            val place = widgetData.getString("r_place", "Alerta Granizo") ?: "Alerta Granizo"
            v.setTextViewText(R.id.r_place, place.uppercase())
            v.setTextViewText(R.id.r_label, widgetData.getString("r_label", "—"))
            v.setTextViewText(R.id.r_headline, widgetData.getString("r_headline", "Abrí la app"))
            v.setTextViewText(R.id.r_storm, widgetData.getString("r_storm", ""))
            v.setTextViewText(R.id.r_time, widgetData.getString("r_time", ""))
            val i = widgetData.getInt("r_idx", 0).coerceIn(0, 4)
            v.setInt(R.id.r_sq, "setColorFilter", colors[i])
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
