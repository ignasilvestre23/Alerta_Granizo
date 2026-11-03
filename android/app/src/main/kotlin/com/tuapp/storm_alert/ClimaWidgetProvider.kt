package com.tuapp.storm_alert

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ClimaWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_HOURS = "ALERTA_GRANIZO_WIDGET_HOURS"
        const val ACTION_DAYS = "ALERTA_GRANIZO_WIDGET_DAYS"
    }

    // Toque en "Horas" / "Días": cambia el modo y redibuja.
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val mode = when (intent.action) {
            ACTION_HOURS -> "hours"
            ACTION_DAYS -> "days"
            else -> return
        }
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().putString("c_mode", mode).apply()
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, ClimaWidgetProvider::class.java))
        onUpdate(context, mgr, ids, prefs)
    }

    private fun tabIntent(context: Context, action: String, code: Int): PendingIntent {
        val i = Intent(context, ClimaWidgetProvider::class.java).setAction(action)
        return PendingIntent.getBroadcast(
            context, code, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

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
        val days = widgetData.getString("c_mode", "hours") == "days"

        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_clima)
            v.setOnClickPendingIntent(
                R.id.clima_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            v.setOnClickPendingIntent(R.id.c_tab_h, tabIntent(context, ACTION_HOURS, 1))
            v.setOnClickPendingIntent(R.id.c_tab_d, tabIntent(context, ACTION_DAYS, 2))

            val place = widgetData.getString("c_place", "Alerta Granizo") ?: "Alerta Granizo"
            v.setTextViewText(R.id.c_place, place.uppercase())
            v.setTextViewText(R.id.c_icon, widgetData.getString("c_icon", "☁️"))
            v.setTextViewText(R.id.c_temp, widgetData.getString("c_temp", "--°"))
            v.setTextViewText(R.id.c_cond, widgetData.getString("c_cond", "Abrí la app"))
            v.setTextViewText(R.id.c_range, widgetData.getString("c_range", ""))
            v.setTextViewText(R.id.c_risk, widgetData.getString("c_risk", ""))
            v.setTextViewText(R.id.c_time, widgetData.getString("c_time", ""))
            val idx = widgetData.getInt("c_idx", 0).coerceIn(0, 4)
            v.setInt(R.id.c_sq, "setColorFilter", colors[idx])

            // Pestañas
            v.setInt(R.id.c_tab_h, "setBackgroundResource", if (!days) R.drawable.tab_selected else 0)
            v.setInt(R.id.c_tab_d, "setBackgroundResource", if (days) R.drawable.tab_selected else 0)
            v.setTextColor(R.id.c_tab_h, Color.parseColor(if (!days) "#FFFFFF" else "#8E97A5"))
            v.setTextColor(R.id.c_tab_d, Color.parseColor(if (days) "#FFFFFF" else "#8E97A5"))

            // Columnas (5 horas o 5 días)
            v.removeAllViews(R.id.c_cols)
            val p = if (days) "d" else "h"
            for (n in 0 until 5) {
                val col = RemoteViews(context.packageName, R.layout.widget_clima_col)
                col.setTextViewText(R.id.col_label, widgetData.getString("${p}${n}_l", ""))
                col.setTextViewText(R.id.col_emoji, widgetData.getString("${p}${n}_e", ""))
                col.setTextViewText(R.id.col_temp, widgetData.getString("${p}${n}_t", ""))
                if (days) {
                    col.setTextViewText(R.id.col_min, widgetData.getString("d${n}_m", ""))
                    col.setViewVisibility(R.id.col_min, View.VISIBLE)
                } else {
                    col.setViewVisibility(R.id.col_min, View.GONE)
                }
                v.addView(R.id.c_cols, col)
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
