package io.github.kulitorum.decenza_de1;

import android.content.Intent;
import android.os.Bundle;

import org.qtproject.qt.android.bindings.QtActivity;

public class DecenzaActivity extends QtActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        StorageHelper.init(this);

        // Start the shutdown service so onTaskRemoved() will be called
        // when the app is swiped away from recent tasks
        Intent serviceIntent = new Intent(this, DeviceShutdownService.class);
        startService(serviceIntent);
    }
}
