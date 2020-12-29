package com.fyp.pawsearch;


import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import com.bumptech.glide.Glide;
import com.bumptech.glide.load.DataSource;
import com.bumptech.glide.load.engine.GlideException;
import com.bumptech.glide.request.RequestListener;
import com.bumptech.glide.request.target.CustomTarget;
import com.bumptech.glide.request.target.Target;
import com.bumptech.glide.request.transition.Transition;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QueryDocumentSnapshot;
import com.google.firebase.firestore.QuerySnapshot;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.OnProgressListener;
import com.google.firebase.storage.UploadTask;

import org.opencv.android.BaseLoaderCallback;
import org.opencv.android.LoaderCallbackInterface;
import org.opencv.android.OpenCVLoader;
import org.opencv.android.Utils;
import org.opencv.core.DMatch;
import org.opencv.core.Mat;
import org.opencv.core.MatOfByte;
import org.opencv.core.MatOfDMatch;
import org.opencv.core.MatOfKeyPoint;
import org.opencv.core.Scalar;
import org.opencv.features2d.DescriptorMatcher;
import org.opencv.features2d.Feature2D;
import org.opencv.features2d.Features2d;
import org.opencv.features2d.ORB;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.res.ResourcesCompat;
import androidx.fragment.app.FragmentActivity;


public class OpenCVActivity extends FragmentActivity  {

    //global variables
    ORB detector;
    Feature2D descriptor;
    DescriptorMatcher matcher;
    Mat img1,img2;
    Mat descriptors2,descriptors1;
    MatOfKeyPoint matOfKeyPoint1, matOfKeyPoint2;

    private ImageView matchIV;
    private TextView matchPerc;
    private ImageView pb;
    private TextView loading;
    private TextView date;
    private TextView locationTV;
    private Button contact;
    private Button report;
    private Button goBack;
    private Dialog dialog;
    private ScrollView scrollView;
    private LinearLayout matchLayout;
    private TextView similarTV;

    private File file;
    private Bitmap targetImage;
    private String breed;
    private String searchType;
    private int index = 0;
    private double highestMatch = 0.0;
    private QueryDocumentSnapshot highestPet;
    private SharedPreferences pref;
    private String uid;
    private GoogleMap mapAPI, mapAPI2;
    private BetterScrollMap mapFragment;
    private boolean locationPermissionGranted;
    private BetterScrollMap currMap;
    private String reportLocation = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_open_c_v);

        //custom App Bar
        getActionBar().setBackgroundDrawable(new ColorDrawable());
        getActionBar().setDisplayShowCustomEnabled(true);
        getActionBar().setCustomView(R.layout.customappbar);

        //initialize view
        matchIV = (ImageView) findViewById(R.id.matchIV);
        matchPerc = (TextView) findViewById(R.id.matchPerc);
        loading = (TextView) findViewById(R.id.loadingTV);
        locationTV = (TextView) findViewById(R.id.locationTV);
        pb = (ImageView) findViewById(R.id.loadingPB);
        date = (TextView) findViewById(R.id.postDate);
        contact = (Button) findViewById(R.id.contact);
        report = (Button) findViewById(R.id.report);
        goBack = (Button) findViewById(R.id.goback);
        scrollView = (ScrollView) findViewById(R.id.scrollLayout);
        matchLayout = (LinearLayout) findViewById(R.id.matchedLayout);
        similarTV = (TextView)findViewById(R.id.similarTV);

        //initialize Google Map & Location
        mapFragment = (BetterScrollMap) getSupportFragmentManager().findFragmentById(R.id.mapAPI);
        mapFragment.getMapAsync(onMapReadyCallback1());
        mapFragment.getView().setVisibility(View.GONE);
        ((BetterScrollMap) getSupportFragmentManager().findFragmentById(R.id.mapAPI)).setListener(new BetterScrollMap.OnTouchListener() {
            @Override
            public void onTouch() {
                scrollView.requestDisallowInterceptTouchEvent(true);
            }
        });

        //initialize SharedPreference UID
        pref = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        uid = pref.getString("flutter.uid", "Can't find the UID");

        //Go back to Flutter
        goBack.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });

        //Load loading asset on build created
        Glide.with(OpenCVActivity.this).load(R.drawable.loading).listener(new RequestListener<Drawable>() {
            @Override
            public boolean onLoadFailed(@Nullable GlideException e, Object model, Target<Drawable> target, boolean isFirstResource) {
                return false;
            }

            @Override
            public boolean onResourceReady(Drawable resource, Object model, Target<Drawable> target, DataSource dataSource, boolean isFirstResource) {
                pb.setVisibility(View.VISIBLE);
                return false;
            }
        }).into(pb);

        //initialize values from intent
        breed = getIntent().getStringExtra("breed");    //Get Breed
        if(getIntent().getStringExtra("type").equals("lost")){  //Get Search Type
            searchType = "Found";
        }
        else{
            searchType = "Lost";
        }
        //Get Target Image file
        boolean error = false;
        String fileName = getIntent().getStringExtra("imageSrc").split("cache/")[1];
        fileName = fileName.substring(0,fileName.length()-1);   //Remove ' apostrophe
        file = new File("/data/data/com.fyp.pawsearch/cache/",fileName);
        //Check through all available cache directories
        if(!file.exists()){
            file = new File(this.getExternalCacheDir(),fileName);
            if(!file.exists()){
                file = new File(this.getCacheDir(),fileName);
                if(!file.exists()){
                    file = new File(this.getApplicationInfo().dataDir+"/cache/",fileName);
                }
                else{
                    error = true;
                    Toast.makeText(OpenCVActivity.this, "File not Found!", Toast.LENGTH_SHORT).show();
                }
            }
        }
        if(!error) {    //Only decode when File is found in cache
            targetImage = BitmapFactory.decodeFile(file.getPath());
        }

        //show loading box
        dialog = new Dialog(OpenCVActivity.this);
        AlertDialog.Builder builder = new AlertDialog.Builder(OpenCVActivity.this);
        builder.setTitle("Loading")
                .setMessage("Please wait while OpenCV loads up")
                .setCancelable(false);
        dialog = builder.create();
        dialog.show();

        //Check OpenCV loading status
        if(!OpenCVLoader.initDebug()){
            Log.i("info","Failed to load OpenCV during startup");
        }
        else{
            //only initialize openCV in onCreate after it is successfully loaded
            initializesOpenCV();
            dialog.dismiss();

            //Start getting images from database
            if(!error) {
                getImages(searchType, breed);
            }
        }

    }

    //Function to get images from Firebase before comparisons
    private void getImages(String searchType, String breed){
        //Conduct search through database
        FirebaseFirestore.getInstance().collection(searchType).whereEqualTo("breed",breed)
                .get()
                .addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
            @Override
            public void onComplete(@NonNull Task<QuerySnapshot> task) {
                if(task.isSuccessful()){
                    if(task.getResult().size()>0) {
                        //for each document of the breed found
                        for (QueryDocumentSnapshot document : task.getResult()) {
                            index++;
                            if(!OpenCVActivity.this.isFinishing()) {
                                //Load each image from url as bitmap for OpenCV usage
                                Glide.with(OpenCVActivity.this).asBitmap().load(document.getString("url")).into(new CustomTarget<Bitmap>() {
                                    @Override
                                    public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                        //Start comparing every bitmap in openCV function
                                        double result = startComparison(resource);
                                        Log.i("COMPARE", result + "");

                                        //Only when the percentage is above 50% and is higher than the highest
                                        if (result > highestMatch && result > 50) {
                                            //conduct replacement of highest percentage
                                            highestMatch = result;
                                            highestPet = document;  //Get the highest matched result
                                        }
                                        Log.i("HIGHEST", highestMatch + "");
                                        if (index == task.getResult().size()) {
                                            //Conduct at last document (decision)
                                            if (highestPet != null) {   //If there's result
                                                displayResult(false);
                                            } else {   //If all the matching are too low percentage
                                                displayResult(true);
                                            }

                                        }
                                    }

                                    @Override
                                    public void onLoadCleared(@Nullable Drawable placeholder) {
                                    }
                                });
                            }
                        }
                    }
                    else{   //If there's no result for the breed found
                        pb.setVisibility(View.GONE);
                        matchPerc.setVisibility(View.GONE);
                        loading.setText("Unfortunately...currently we do not have any "+searchType+" report on " + breed);
                        loading.setTextColor(Color.parseColor("#FF5252"));
                        loading.setTextSize(16);
                        report.setVisibility(View.VISIBLE);
                        report.setEnabled(true);
                        report.setOnClickListener(new View.OnClickListener() {
                            @Override
                            public void onClick(View v) {
                                reportDialog();
                            }
                        });
                    }
                }
            }
        }).addOnFailureListener(new OnFailureListener() {
            @Override
            public void onFailure(@NonNull Exception e) {
                Toast.makeText(OpenCVActivity.this, "Get from DB failed! Exception: "+e.toString(), Toast.LENGTH_SHORT).show();
            }
        });
    }

    //Function to scale bitmap images into same size of 500x500 for comparison
    private Bitmap scaleBitmap(Bitmap bm, int maxWidth, int maxHeight) {
        int width = bm.getWidth();
        int height = bm.getHeight();

        if (width > height) {
            // landscape
            float ratio = (float) width / maxWidth;
            width = maxWidth;
            height = (int)(height / ratio);
        } else if (height > width) {
            // portrait
            float ratio = (float) height / maxHeight;
            height = maxHeight;
            width = (int)(width / ratio);
        } else {
            // square
            height = maxHeight;
            width = maxWidth;
        }

        bm = Bitmap.createScaledBitmap(bm, width, height, true);
        return bm;
    }

    //Function to conduct image comparisons
    private double startComparison(Bitmap compareImg){

            //Scale both images into same size for more accurate result
            //Convert Target and Search Bitmap to Mat format
            Utils.bitmapToMat(scaleBitmap(targetImage,500,500),img1);
            Utils.bitmapToMat(scaleBitmap(compareImg,500,500),img2);

            //Start Feature Extraction with ORB Algo
            detector.detect(img1,matOfKeyPoint1);
            descriptor.compute(img1,matOfKeyPoint1,descriptors1);
            detector.detect(img2,matOfKeyPoint2);
            descriptor.compute(img2,matOfKeyPoint2,descriptors2);

            //Start Matching
            MatOfDMatch matches = new MatOfDMatch();
            matcher.match(descriptors1, descriptors2, matches);
            List<DMatch> matchesList = matches.toList();
            //Maximum and minimum distances between keypoints
            Double max_dist = 0.0;
            Double min_dist = 100.0;

            for (int i = 0; i < matchesList.size(); i++) {
                Double dist = (double) matchesList.get(i).distance;
                if (dist < min_dist)
                    min_dist = dist;
                if (dist > max_dist)
                    max_dist = dist;
            }

            //feature and connection colors
            Scalar RED = new Scalar(255,0,0);
            Scalar GREEN = new Scalar(0,255,0);

            //output image
            Mat outputImg = new Mat();
            MatOfByte drawnMatches = new MatOfByte();
            //draw all matches
            Features2d.drawMatches(img1, matOfKeyPoint1, img2, matOfKeyPoint2, matches,
                    outputImg, GREEN, RED, drawnMatches, Features2d.DrawMatchesFlags_NOT_DRAW_SINGLE_POINTS);
            Bitmap imageMatched = Bitmap.createBitmap(outputImg.cols(), outputImg.rows(), Bitmap.Config.RGB_565);
            Utils.matToBitmap(outputImg, imageMatched);

            //Calculate Good matches (distance less than ) to distinguish and limit unnecessary match points.
            LinkedList<DMatch> good_matches = new LinkedList<DMatch>();
            for (int i = 0; i < matchesList.size(); i++) {  //If same image found, wont be distinguished with == min distance checking
                if (matchesList.get(i).distance > (2 * min_dist) || matchesList.get(i).distance == min_dist) {
                    good_matches.addLast(matchesList.get(i));
                }
            }

            //If Good Match Result list is not empty (When the percentage is > 0)
            if(matchesList.size()>0 && good_matches.size()>0) {
                //Calculate Match Percentage
                double matchPercent = (100 * good_matches.size()) / matchesList.size();
                //Show similar results on matches made on screen with percentage
                LinearLayout matchedInner = new LinearLayout(OpenCVActivity.this);
                matchedInner.setOrientation(LinearLayout.VERTICAL);
                //Set Percentage
                TextView percentagePerSearch = new TextView(OpenCVActivity.this);
                percentagePerSearch.setGravity(Gravity.CENTER);
                percentagePerSearch.setTextColor(Color.parseColor("#263238"));
                percentagePerSearch.setTypeface(ResourcesCompat.getFont(OpenCVActivity.this,R.font.baloo));
                percentagePerSearch.setText(matchPercent+"%");
                //Set Image
                ImageView matchedImg = new ImageView(OpenCVActivity.this);
                matchedImg.setImageBitmap(imageMatched);
                matchedImg.setPadding(8,8,8,8);
                matchedImg.setAdjustViewBounds(true);
                matchedImg.setMaxWidth(300);
                matchedImg.setMaxHeight(300);
                //Add views into vertical inner Linear Layout representing one per search
                matchedInner.addView(matchedImg);
                matchedInner.addView(percentagePerSearch);
                //Add the inner layout into the Horizontal Linear Layout
                matchLayout.addView(matchedInner);
                return matchPercent;
            }
            //No match found
            else{
                return 0.0;
            }
//Convert to greyscale not necessary, wont affect ORB algo
//        Bitmap res1 = BitmapFactory.decodeResource(this.getResources(),R.drawable.husky1);
//        Bitmap res2 = BitmapFactory.decodeResource(this.getResources(),R.drawable.husky3);
//        Utils.bitmapToMat(res1,img1);
//        Utils.bitmapToMat(res2,img2);
//        Imgproc.cvtColor(img1,img1,Imgproc.COLOR_RGB2GRAY);
//        Imgproc.cvtColor(img2,img2,Imgproc.COLOR_RGB2GRAY);

    }

    //Function to Display Result after last comparison
    private void displayResult(boolean noResult){

        if(!noResult) {

            //Set view values
            similarTV.setVisibility(View.VISIBLE);
            locationTV.setVisibility(View.VISIBLE);
            mapFragment.getView().setVisibility(View.VISIBLE);
            loading.setVisibility(View.GONE);
            date.setText("Date: " + highestPet.getString("foundDate"));
            matchPerc.setText("Match Found with Percentage of " + String.format("%.2f", highestMatch) + " %");

            if (!OpenCVActivity.this.isFinishing()) {
                //Load final result Image View
                Glide.with(OpenCVActivity.this).load(highestPet.getString("url")).listener(new RequestListener<Drawable>() {
                    @Override
                    public boolean onLoadFailed(@Nullable GlideException e, Object model, Target<Drawable> target, boolean isFirstResource) {
                        Toast.makeText(OpenCVActivity.this, "Image load failed! Exception: " + e.toString(), Toast.LENGTH_SHORT).show();
                        return false;
                    }

                    @Override
                    public boolean onResourceReady(Drawable resource, Object model, Target<Drawable> target, DataSource dataSource, boolean isFirstResource) {
                        pb.setVisibility(View.GONE);
                        return false;
                    }
                }).into(matchIV);
            }

            //Show Pet Location on Google map
            LatLng latLng;
            if (highestPet.getString("location") != null && highestPet.getString("location").length() > 0 && highestPet.getString("location").contains(",")) {
                latLng = new LatLng(Double.parseDouble(highestPet.getString("location").split(", ")[0]), Double.parseDouble(highestPet.getString("location").split(", ")[1]));
            } else {
                latLng = new LatLng(0.0, 0.0);
            }
            mapAPI.clear();
            MarkerOptions options = new MarkerOptions().position(latLng).title("Pet Location");
            mapAPI.animateCamera(CameraUpdateFactory.newLatLngZoom(latLng, 15));
            mapAPI.addMarker(options).showInfoWindow();
            mapAPI.getUiSettings().setZoomControlsEnabled(true);
            mapAPI.getUiSettings().setAllGesturesEnabled(true);

            //Get Post Owner Name from database
            FirebaseFirestore.getInstance().collection("User").document(highestPet.getString("postOwner")).get()
                    .addOnCompleteListener(new OnCompleteListener<DocumentSnapshot>() {
                        @Override
                        public void onComplete(@NonNull Task<DocumentSnapshot> task) {
                            if (task.isSuccessful()) {
                                report.setVisibility(View.VISIBLE);
                                report.setEnabled(true);
                                report.setOnClickListener(new View.OnClickListener() {
                                    @Override
                                    public void onClick(View v) {
                                        reportDialog();
                                    }
                                });
                                contact.setVisibility(View.VISIBLE);
                                contact.setEnabled(true);
                                contact.setText("View Contact of " + task.getResult().getString("name"));
                                contact.setOnClickListener(new View.OnClickListener() {
                                    @Override
                                    public void onClick(View v) {
                                        //Set layout values for dialog box
                                        ScrollView sv = new ScrollView(OpenCVActivity.this);
                                        LinearLayout ll = new LinearLayout(OpenCVActivity.this);
                                        ll.setOrientation(LinearLayout.VERTICAL);
                                        ll.setGravity(Gravity.CENTER);
                                        ll.setPadding(32, 32, 32, 32);

                                        TextView nameTV = new TextView(OpenCVActivity.this);
                                        nameTV.setTextColor(Color.parseColor("#263238"));
                                        nameTV.setTypeface(ResourcesCompat.getFont(OpenCVActivity.this, R.font.baloo));
                                        nameTV.setText("Name: " + task.getResult().getString("name"));
                                        nameTV.setTextSize(16);
                                        nameTV.setPadding(36, 32, 36, 32);

                                        TextView hpTV = new TextView(OpenCVActivity.this);
                                        hpTV.setTextColor(Color.parseColor("#263238"));
                                        hpTV.setTypeface(ResourcesCompat.getFont(OpenCVActivity.this, R.font.baloo));
                                        hpTV.setText("Contact No.: " + task.getResult().getString("hp"));
                                        hpTV.setTextSize(16);
                                        hpTV.setPadding(36, 32, 36, 32);

                                        LinearLayout.LayoutParams phoneParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                                        phoneParams.setMargins(8, 8, 8, 32);
                                        ImageButton phone = new ImageButton(OpenCVActivity.this);
                                        phone.setImageResource(android.R.drawable.sym_action_call);
                                        phone.setBackgroundResource(R.drawable.roundedbutton);
                                        phone.setLayoutParams(phoneParams);
                                        phone.setOnClickListener(new View.OnClickListener() {
                                            @Override
                                            public void onClick(View v) {
                                                Intent intent = new Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + task.getResult().getString("hp")));
                                                startActivity(intent);
                                            }
                                        });

                                        LinearLayout.LayoutParams waParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                                        waParams.setMargins(8, 0, 8, 0);
                                        ImageButton whatsapp = new ImageButton(OpenCVActivity.this);
                                        whatsapp.setImageResource(R.drawable.walogo);
                                        whatsapp.setBackgroundResource(R.drawable.roundedbutton);
                                        whatsapp.setAdjustViewBounds(true);
                                        whatsapp.setMaxHeight(150);
                                        whatsapp.setOnClickListener(new View.OnClickListener() {
                                            @Override
                                            public void onClick(View v) {
                                                String url = "https://api.whatsapp.com/send?phone=" + task.getResult().getString("hp");
                                                Intent i = new Intent(Intent.ACTION_VIEW);
                                                i.setData(Uri.parse(url));
                                                startActivity(i);
                                            }
                                        });

                                        ll.addView(nameTV);
                                        ll.addView(hpTV);
                                        ll.addView(phone);
                                        ll.addView(whatsapp);
                                        sv.addView(ll);
                                        //Show dialog
                                        AlertDialog contactDialog;
                                        AlertDialog.Builder builder = new AlertDialog.Builder(OpenCVActivity.this);
                                        builder.setTitle("Contact Details")
                                                .setIcon(android.R.drawable.ic_menu_call)
                                                .setView(sv)
                                                .setPositiveButton("Dismiss", new DialogInterface.OnClickListener() {
                                                    @Override
                                                    public void onClick(DialogInterface dialog, int which) {
                                                        dialog.dismiss();
                                                    }
                                                });
                                        contactDialog = builder.create();
                                        contactDialog.getWindow().setBackgroundDrawableResource(R.drawable.roundeddialog);
                                        contactDialog.show();
                                        contactDialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(Color.parseColor("#2196F3"));

                                    }
                                });
                            }
                        }
                    });
        }
        else{
            //Set view values
            pb.setVisibility(View.GONE);
            similarTV.setVisibility(View.VISIBLE);
            loading.setText("Unfortunately...we could not find any match of the pet with a reliable percentage. If you happen to find your pet in the below Similar Results section, please try again with a different image of your pet.");
            loading.setTextColor(Color.parseColor("#FF5252"));
            loading.setTextSize(16);
            matchPerc.setText("No Confident Match Found!");
            report.setVisibility(View.VISIBLE);
            report.setEnabled(true);
            report.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    reportDialog();
                }
            });
        }

    }

    //Function to file report
    private void reportDialog(){
        //Set report layout with views
        AlertDialog dialog;

        AlertDialog.Builder builder = new AlertDialog.Builder(OpenCVActivity.this);
        builder
                .setCancelable(false)
                .setPositiveButton("Confirm", null)
                .setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        dialog.dismiss();
                    }
                });
        dialog = builder.setView(R.layout.reportdialog).create();
        dialog.show();
        dialog.setOnDismissListener(new DialogInterface.OnDismissListener() {
            @Override
            public void onDismiss(DialogInterface dialog) {
                if(currMap != null){
                    getSupportFragmentManager().beginTransaction().remove(currMap).commit();
                }
            }
        });
        dialog.getWindow().setBackgroundDrawableResource(R.drawable.roundeddialog);
        dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setTextColor(Color.parseColor("#FF5252"));
        dialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(Color.parseColor("#2196F3"));

        ScrollView sv = (ScrollView) dialog.findViewById(R.id.sv);

        ProgressBar pb = (ProgressBar) dialog.findViewById(R.id.pb);
        pb.setVisibility(View.GONE);

        TextView progressTV = (TextView) dialog.findViewById(R.id.progressTV);

        ImageView petImage = (ImageView) dialog.findViewById(R.id.petImage);
        petImage.setImageBitmap(targetImage);

        TextView reportType = (TextView) dialog.findViewById(R.id.reportType);
        if(searchType.equals("Lost")){
            reportType.setText("Report Type : "+"Found Report");
        }
        else{
            reportType.setText("Report Type : "+"Lost Report");
        }

        TextView postDate = (TextView) dialog.findViewById(R.id.postDate);
        Date c = Calendar.getInstance().getTime();
        SimpleDateFormat df = new SimpleDateFormat("dd-MM-yyyy hh:mm:ss a", Locale.getDefault());
        String formattedDate = df.format(c);
        postDate.setText("Date : "+formattedDate);

        TextView breedTV = (TextView) dialog.findViewById(R.id.breedTV);
        breedTV.setText("Breed Class : "+breed);

        TextView postOwner = (TextView) dialog.findViewById(R.id.postOwner);
        postOwner.setText("Post Owner UID : "+uid);

            currMap = (BetterScrollMap) getSupportFragmentManager().findFragmentById(R.id.currMap);
            currMap.getMapAsync(onMapReadyCallback2());
            ((BetterScrollMap) getSupportFragmentManager().findFragmentById(R.id.currMap)).setListener(new BetterScrollMap.OnTouchListener() {
                @Override
                public void onTouch() {
                    sv.requestDisallowInterceptTouchEvent(true);
                }
            });


        //On Confirm Clicked, Conduct Upload
        dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setEnabled(false);
                dialog.getButton(AlertDialog.BUTTON_POSITIVE).setEnabled(false);
                dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setTextColor(Color.parseColor("#D3D3D3"));
                dialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(Color.parseColor("#D3D3D3"));
                pb.setVisibility(View.VISIBLE);
                String rptType;
                if(searchType.equals("Lost")){
                    rptType = "Found";
                }
                else{
                    rptType = "Lost";
                }
                FirebaseStorage.getInstance().getReference().child(rptType+"Images/"+formattedDate).putFile(Uri.fromFile(file))
                        .addOnProgressListener(new OnProgressListener<UploadTask.TaskSnapshot>() {
                            @Override
                            public void onProgress(@NonNull UploadTask.TaskSnapshot taskSnapshot) {
                                double progress = (100.00*taskSnapshot.getBytesTransferred())/taskSnapshot.getTotalByteCount();
                                pb.setProgress((int)progress);
                                progressTV.setText("Uploading...("+String.format("%.2f", progress)+"%) "+taskSnapshot.getBytesTransferred()+"/"+taskSnapshot.getTotalByteCount()+"bytes");
                            }
                        })
                        .addOnSuccessListener(new OnSuccessListener<UploadTask.TaskSnapshot>() {
                            @Override
                            public void onSuccess(UploadTask.TaskSnapshot taskSnapshot) {
                                //Add to database on upload succeed
                                Task<Uri> downloadUrl = taskSnapshot.getStorage().getDownloadUrl();
                                while (!downloadUrl.isSuccessful());
                                if(downloadUrl.isSuccessful()){
                                    Uri url = downloadUrl.getResult();
                                    Map<String, Object> petReport = new HashMap<>();
                                    petReport.put("url", url.toString());
                                    petReport.put("breed", breed);
                                    petReport.put("location", reportLocation);
                                    petReport.put("foundDate", formattedDate);
                                    petReport.put("postOwner", pref.getString("flutter.uid","Can't find UID"));
                                    petReport.put("type",rptType);
                                    FirebaseFirestore.getInstance().collection(rptType).document(formattedDate).set(petReport)
                                            .addOnCompleteListener(new OnCompleteListener<Void>() {
                                                @Override
                                                public void onComplete(@NonNull Task<Void> task) {
                                                    if(task.isSuccessful()){
                                                        //Close dialog when upload is done
                                                        dialog.dismiss();

                                                        Toast toast = Toast.makeText(OpenCVActivity.this, "Report succesfully filed to Database! Your report can now be found at the home page.", Toast.LENGTH_LONG);
                                                        View view = toast.getView();
                                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                                            view.setForegroundGravity(Gravity.CENTER);
                                                        }
                                                        view.setBackgroundResource(R.drawable.roundedbutton);
                                                        TextView text = (TextView) view.findViewById(android.R.id.message);
                                                        text.setTextColor(Color.parseColor("#FFFFFF"));
                                                        text.setTextSize(16);
                                                        text.setGravity(Gravity.CENTER);
                                                        toast.show();
                                                    }
                                                }
                                            })
                                            .addOnFailureListener(new OnFailureListener() {
                                                @Override
                                                public void onFailure(@NonNull Exception e) {
                                                    Toast.makeText(OpenCVActivity.this, "Add to DB failed: "+e.toString(), Toast.LENGTH_LONG).show();
                                                }
                                            });
                                }
                            }
                        })
                        .addOnFailureListener(new OnFailureListener() {
                            @Override
                            public void onFailure(@NonNull Exception e) {
                                Toast.makeText(OpenCVActivity.this, "Upload Failed: "+e.toString(), Toast.LENGTH_LONG).show();
                            }
                        });
            }
        });

    }

    //Function to initializes OpenCV variables
    private void initializesOpenCV(){
        descriptor = ORB.create();
        detector = ORB.create();
        matcher = DescriptorMatcher.create(DescriptorMatcher.BRUTEFORCE_HAMMING);
        img1 = new Mat();
        img2 = new Mat();
        descriptors1 = new Mat();
        descriptors2 = new Mat();
        matOfKeyPoint1 = new MatOfKeyPoint();
        matOfKeyPoint2 = new MatOfKeyPoint();
    }

    //handle async callback of loading OpenCV
    @Override
    public void onResume() {
        super.onResume();
        if (!OpenCVLoader.initDebug()) {
            Log.d("TAG", "Internal OpenCV library not found. Using OpenCV Manager for initialization");
            OpenCVLoader.initAsync(OpenCVLoader.OPENCV_VERSION, this, mLoaderCallback);
        } else {
            Log.d("TAG", "OpenCV library found inside package. Using it!");
            mLoaderCallback.onManagerConnected(LoaderCallbackInterface.SUCCESS);
        }
    }

    //CallBack method to initializes openCV on load succession
    private BaseLoaderCallback mLoaderCallback = new BaseLoaderCallback(this) {
        @Override
        public void onManagerConnected(int status) {
            switch (status) {
                case LoaderCallbackInterface.SUCCESS: {
                    Log.i("TAG", "OpenCV loaded successfully");
                }
                break;
                default: {
                    super.onManagerConnected(status);
                }
                break;
            }
        }
    };

    public OnMapReadyCallback onMapReadyCallback1(){
        return new OnMapReadyCallback(){
            @Override
            public void onMapReady(GoogleMap googleMap) {
                mapAPI = googleMap;

                updateLocationUI();
            }
        };
    }

    public OnMapReadyCallback onMapReadyCallback2(){
        return new OnMapReadyCallback() {
            @Override
            public void onMapReady(GoogleMap googleMap) {
                mapAPI2 = googleMap;

                updateLocationUI2();
                LatLng latLng = new LatLng(4.2105, 101.9758);
                MarkerOptions options = new MarkerOptions().position(latLng).title("Default Location");
                mapAPI2.animateCamera(CameraUpdateFactory.newLatLngZoom(latLng,5));
                mapAPI2.addMarker(options).showInfoWindow();
                mapAPI2.getUiSettings().setZoomControlsEnabled(true);
                mapAPI2.getUiSettings().setAllGesturesEnabled(true);
                mapAPI2.setOnMapClickListener(new GoogleMap.OnMapClickListener() {
                    @Override
                    public void onMapClick(LatLng latLng) {
                        mapAPI2.clear();
                        reportLocation = latLng.latitude + ", " + latLng.longitude;
                        MarkerOptions options = new MarkerOptions().position(latLng).title("Set Location");
                        mapAPI2.animateCamera(CameraUpdateFactory.newLatLngZoom(latLng,16));
                        mapAPI2.addMarker(options).showInfoWindow();
                    }
                });

            }
        };
    }

    private void updateLocationUI() {
        if (mapAPI == null) {
            return;
        }
        try {
            if (locationPermissionGranted) {
                mapAPI.setMyLocationEnabled(true);
                mapAPI.getUiSettings().setMyLocationButtonEnabled(true);
            } else {
                mapAPI.setMyLocationEnabled(false);
                mapAPI.getUiSettings().setMyLocationButtonEnabled(false);
                getLocationPermission();
            }
        } catch (SecurityException e)  {
            Log.e("Exception: %s", e.getMessage());
        }
    }

    private void updateLocationUI2() {
        if (mapAPI2 == null) {
            return;
        }
        try {
            if (locationPermissionGranted) {
                mapAPI2.setMyLocationEnabled(true);
                mapAPI2.getUiSettings().setMyLocationButtonEnabled(true);
            } else {
                mapAPI2.setMyLocationEnabled(false);
                mapAPI2.getUiSettings().setMyLocationButtonEnabled(false);
                getLocationPermission();
            }
        } catch (SecurityException e)  {
            Log.e("Exception: %s", e.getMessage());
        }
    }

    private void getLocationPermission() {
        if (ContextCompat.checkSelfPermission(this.getApplicationContext(),
                android.Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED) {
            locationPermissionGranted = true;
        } else {
            ActivityCompat.requestPermissions(this,
                    new String[]{android.Manifest.permission.ACCESS_FINE_LOCATION},69
                    );
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        locationPermissionGranted = false;
        switch (requestCode) {
            case 69: {
                // If request is cancelled, the result arrays are empty.
                if (grantResults.length > 0
                        && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    locationPermissionGranted = true;
                }
            }
        }
        updateLocationUI();
    }

}