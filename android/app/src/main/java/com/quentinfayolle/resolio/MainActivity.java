package com.quentinfayolle.resolio;

import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        // module maison : temps d'écran (doit être enregistré avant super.onCreate)
        registerPlugin(ScreenTimePlugin.class);
        super.onCreate(savedInstanceState);
    }
}
