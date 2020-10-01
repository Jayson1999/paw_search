package com.fyp.pawsearch;

import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    //Channel name for Flutter <> Android Method calling
    private static final String CHANNEL = "openCVChannel";
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        //Receive Method Invoke from Flutter Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(((call, result) -> {
                    if(call.method.equals("opencvComparison")){

                        Intent intent = new Intent(MainActivity.this,OpenCVActivity.class);
                        intent.putExtra("breed", call.argument("breed").toString());
                        intent.putExtra("type", call.argument("type").toString());
                        intent.putExtra("imageSrc", call.argument("imageSrc").toString());
                        startActivity(intent);

                    }
                }));
    }


}
