package com.quentinfayolle.resolio;

import android.app.AppOpsManager;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Process;
import android.provider.Settings;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Temps d'écran (Android) : temps passé au premier plan par application et par jour,
 * calculé à partir des événements d'utilisation (même source que le Bien-être numérique).
 *
 * Nécessite l'accès spécial « Accès aux données d'utilisation » (PACKAGE_USAGE_STATS),
 * accordé par l'utilisateur dans les paramètres (méthode openSettings()).
 *
 * JS : plugin('ScreenTime').hasPermission() → { granted }
 *      plugin('ScreenTime').openSettings()
 *      plugin('ScreenTime').getDailyUsage({ days: 7 }) → { days: [{ date: 'YYYY-MM-DD', apps: [{ package, name, category, minutes }] }] }
 */
@CapacitorPlugin(name = "ScreenTime")
public class ScreenTimePlugin extends Plugin {

    // UsageEvents.Event : valeurs numériques (stables) pour rester compatible avec toutes les versions d'Android
    private static final int EV_RESUMED = 1;          // ACTIVITY_RESUMED (MOVE_TO_FOREGROUND)
    private static final int EV_PAUSED = 2;           // ACTIVITY_PAUSED (MOVE_TO_BACKGROUND)
    private static final int EV_SCREEN_OFF = 16;      // SCREEN_NON_INTERACTIVE
    private static final int EV_STOPPED = 23;         // ACTIVITY_STOPPED
    private static final int EV_SHUTDOWN = 26;        // DEVICE_SHUTDOWN

    private boolean granted() {
        Context ctx = getContext();
        AppOpsManager ops = (AppOpsManager) ctx.getSystemService(Context.APP_OPS_SERVICE);
        int mode;
        if (Build.VERSION.SDK_INT >= 29) {
            mode = ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.getPackageName());
        } else {
            mode = ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.getPackageName());
        }
        if (mode == AppOpsManager.MODE_DEFAULT) {
            return ctx.checkCallingOrSelfPermission("android.permission.PACKAGE_USAGE_STATS") == PackageManager.PERMISSION_GRANTED;
        }
        return mode == AppOpsManager.MODE_ALLOWED;
    }

    @PluginMethod
    public void hasPermission(PluginCall call) {
        JSObject r = new JSObject();
        r.put("granted", granted());
        call.resolve(r);
    }

    @PluginMethod
    public void openSettings(PluginCall call) {
        Context ctx = getContext();
        Intent i = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
        i.setData(Uri.parse("package:" + ctx.getPackageName()));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            ctx.startActivity(i);
        } catch (Exception e) {
            Intent j = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
            j.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            ctx.startActivity(j);
        }
        call.resolve();
    }

    @PluginMethod
    public void getDailyUsage(final PluginCall call) {
        if (!granted()) {
            call.reject("Accès aux données d'utilisation non autorisé", "NO_PERMISSION");
            return;
        }
        Integer d = call.getInt("days", 7);
        final int days = Math.max(1, Math.min(31, d == null ? 7 : d));
        execute(new Runnable() {
            @Override
            public void run() {
                try {
                    call.resolve(compute(days));
                } catch (Exception e) {
                    call.reject("Lecture du temps d'écran impossible : " + e.getMessage(), "ERROR");
                }
            }
        });
    }

    private JSObject compute(int days) {
        Context ctx = getContext();
        UsageStatsManager usm = (UsageStatsManager) ctx.getSystemService(Context.USAGE_STATS_SERVICE);
        PackageManager pm = ctx.getPackageManager();

        // applications ignorées : Resolio, l'interface système et l'écran d'accueil (comme le Bien-être numérique)
        Set<String> ignore = new HashSet<>();
        ignore.add(ctx.getPackageName());
        ignore.add("com.android.systemui");
        Intent home = new Intent(Intent.ACTION_MAIN);
        home.addCategory(Intent.CATEGORY_HOME);
        for (ResolveInfo ri : pm.queryIntentActivities(home, 0)) {
            if (ri.activityInfo != null) ignore.add(ri.activityInfo.packageName);
        }

        // débuts de journée (heure locale) : days[0] = il y a (days-1) jours, ..., days[n-1] = aujourd'hui
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, 0);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        c.add(Calendar.DAY_OF_MONTH, -(days - 1));
        final long[] dayStart = new long[days + 1];
        final String[] dayKey = new String[days];
        for (int i = 0; i <= days; i++) {
            dayStart[i] = c.getTimeInMillis();
            if (i < days) {
                dayKey[i] = String.format(Locale.US, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH));
            }
            c.add(Calendar.DAY_OF_MONTH, 1);
        }
        long now = System.currentTimeMillis();

        // millisecondes par jour et par application
        List<Map<String, Long>> perDay = new ArrayList<>();
        for (int i = 0; i < days; i++) perDay.add(new HashMap<String, Long>());

        Map<String, Integer> openCount = new HashMap<>();
        Map<String, Long> openSince = new HashMap<>();
        UsageEvents events = usm.queryEvents(dayStart[0], now);
        UsageEvents.Event e = new UsageEvents.Event();
        while (events.hasNextEvent()) {
            events.getNextEvent(e);
            String p = e.getPackageName();
            long t = e.getTimeStamp();
            int type = e.getEventType();
            if (type == EV_RESUMED) {
                int n = openCount.containsKey(p) ? openCount.get(p) : 0;
                if (n == 0) openSince.put(p, t);
                openCount.put(p, n + 1);
            } else if (type == EV_PAUSED || type == EV_STOPPED) {
                int n = openCount.containsKey(p) ? openCount.get(p) : 0;
                if (n <= 0) continue;
                if (n == 1) {
                    Long s = openSince.remove(p);
                    if (s != null) add(perDay, dayStart, p, s, t);
                    openCount.remove(p);
                } else {
                    openCount.put(p, n - 1);
                }
            } else if (type == EV_SCREEN_OFF || type == EV_SHUTDOWN) {
                for (Map.Entry<String, Long> o : openSince.entrySet()) add(perDay, dayStart, o.getKey(), o.getValue(), t);
                openSince.clear();
                openCount.clear();
            }
        }
        for (Map.Entry<String, Long> o : openSince.entrySet()) add(perDay, dayStart, o.getKey(), o.getValue(), now);

        // résultat
        Map<String, String[]> infoCache = new HashMap<>();
        JSArray out = new JSArray();
        for (int i = 0; i < days; i++) {
            JSArray apps = new JSArray();
            for (Map.Entry<String, Long> a : perDay.get(i).entrySet()) {
                String p = a.getKey();
                if (ignore.contains(p)) continue;
                double minutes = Math.round(a.getValue() / 6000.0) / 10.0;   // minutes, 1 décimale
                if (minutes < 0.5) continue;
                String[] info = infoCache.get(p);
                if (info == null) {
                    info = appInfo(pm, p);
                    infoCache.put(p, info);
                }
                JSObject app = new JSObject();
                app.put("package", p);
                app.put("name", info[0]);
                app.put("category", info[1]);
                app.put("minutes", Math.min(1440, minutes));
                apps.put(app);
            }
            JSObject day = new JSObject();
            day.put("date", dayKey[i]);
            day.put("apps", apps);
            out.put(day);
        }
        JSObject r = new JSObject();
        r.put("days", out);
        return r;
    }

    // ajoute l'intervalle [from, to] en le découpant par jour
    private static void add(List<Map<String, Long>> perDay, long[] dayStart, String p, long from, long to) {
        if (to <= from) return;
        for (int i = 0; i < perDay.size(); i++) {
            long a = Math.max(from, dayStart[i]), b = Math.min(to, dayStart[i + 1]);
            if (b > a) {
                Map<String, Long> m = perDay.get(i);
                Long prev = m.get(p);
                m.put(p, (prev == null ? 0L : prev) + (b - a));
            }
        }
    }

    // nom affiché + catégorie déclarée par l'application (Android 8+)
    private static String[] appInfo(PackageManager pm, String p) {
        try {
            ApplicationInfo ai = pm.getApplicationInfo(p, 0);
            String name = String.valueOf(pm.getApplicationLabel(ai));
            String cat = "other";
            if (Build.VERSION.SDK_INT >= 26) {
                switch (ai.category) {
                    case 0: cat = "game"; break;
                    case 1: cat = "audio"; break;
                    case 2: cat = "video"; break;
                    case 3: cat = "image"; break;
                    case 4: cat = "social"; break;
                    case 5: cat = "news"; break;
                    case 6: cat = "maps"; break;
                    case 7: cat = "productivity"; break;
                    case 8: cat = "accessibility"; break;
                    default: cat = "other";
                }
            }
            return new String[] { name, cat };
        } catch (Exception ex) {
            return new String[] { p, "other" };
        }
    }
}
