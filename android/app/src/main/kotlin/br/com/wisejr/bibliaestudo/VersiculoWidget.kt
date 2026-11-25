package br.com.wisejr.bibliaestudo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Widget do versículo do dia na tela inicial.
 *
 * O lado Dart (lib/dados/widget_versiculo.dart) grava, a cada abertura do app,
 * o texto dos próximos 14 dias na chave "versiculos", como
 * {"2026-11-25": {"ref": "João 3:16 (ARA)", "texto": "..."}}. Aqui só se
 * escolhe o de hoje: o widget é redesenhado a cada poucas horas
 * (updatePeriodMillis em res/xml/widget_versiculo_info.xml) e troca de
 * versículo sozinho depois da meia-noite, sem abrir o app.
 */
class VersiculoWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val hoje = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        var referencia = "Versículo do dia"
        var texto = "Abra a Bíblia de Estudo para ver o versículo de hoje."
        try {
            val dias = JSONObject(widgetData.getString("versiculos", null) ?: "{}")
            val dia = dias.optJSONObject(hoje)
            if (dia != null) {
                referencia = dia.optString("ref", referencia)
                texto = dia.optString("texto", texto)
            }
        } catch (_: Exception) {
            // Dado inválido: fica o convite para abrir o app.
        }
        val toque = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("bibliaestudo://hoje"),
        )
        for (id in appWidgetIds) {
            val vista = RemoteViews(context.packageName, R.layout.widget_versiculo)
            vista.setTextViewText(R.id.widget_texto, texto)
            vista.setTextViewText(R.id.widget_referencia, referencia)
            vista.setOnClickPendingIntent(R.id.widget_raiz, toque)
            appWidgetManager.updateAppWidget(id, vista)
        }
    }
}
