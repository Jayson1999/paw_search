package com.fyp.pawsearch;


import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
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
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QueryDocumentSnapshot;
import com.google.firebase.firestore.QuerySnapshot;

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
import java.util.LinkedList;
import java.util.List;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.res.ResourcesCompat;


public class OpenCVActivity extends Activity {

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
    private Button contact;
    private Dialog dialog;

    private Bitmap targetImage;
    private String breed;
    private String searchType;
    private int index = 0;
    private double highestMatch = 0.0;
    private QueryDocumentSnapshot highestPet;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_open_c_v);

        //custom App Bar
        getActionBar().setTitle("Image Matching");
        getActionBar().setIcon(android.R.drawable.ic_menu_search);

        //initialize view
        matchIV = (ImageView) findViewById(R.id.matchIV);
        matchPerc = (TextView) findViewById(R.id.matchPerc);
        loading = (TextView) findViewById(R.id.loadingTV);
        pb = (ImageView) findViewById(R.id.loadingPB);
        date = (TextView) findViewById(R.id.date);
        contact = (Button) findViewById(R.id.contact);
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
        File file = new File("/data/data/com.fyp.pawsearch/cache/",fileName);
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
                    Log.i("CANNOT",file.getPath());
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
                            //Load each image from url as bitmap for OpenCV usage
                            Glide.with(OpenCVActivity.this).asBitmap().load(document.getString("url")).into(new CustomTarget<Bitmap>() {
                                @Override
                                public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                    //Start comparing every bitmap in openCV function
                                    //TODO: Filter lower percentage result
                                    double result = startComparison(resource);
                                    Log.i("COMPARE", result + "");
                                    if (result >= highestMatch) {
                                        highestMatch = result;
                                        highestPet = document;  //Get the highest matched result
                                    }
                                    Log.i("HIGHEST", highestMatch + "");
                                    //TODO: Handle empty result
                                    if (index == task.getResult().size()) {
                                        //Conduct at last document (decision)
                                        if (highestPet != null) {   //If there's result
                                            displayResult();
                                        } else {   //If all the matching are too low percentage

                                        }

                                    }
                                }
                                @Override
                                public void onLoadCleared(@Nullable Drawable placeholder) {
                                }
                            });
                        }
                    }
                    else{   //If there's no result for the breed found
                        pb.setVisibility(View.GONE);
                        matchPerc.setVisibility(View.GONE);
                        loading.setText("Unfortunately...currently we do not have any "+searchType+" report on " + breed);
                        loading.setTextColor(Color.parseColor("#FF5252"));
                        loading.setTextSize(16);
                        contact.setText("Go Back");
                        contact.setOnClickListener(new View.OnClickListener() {
                            @Override
                            public void onClick(View v) {
                                finish();
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

    //Function to conduct image comparisons
    private double startComparison(Bitmap compareImg){
            //Convert Target Search Bitmap to Mat format
            Utils.bitmapToMat(targetImage,img1);

            //Convert to Mat
            Utils.bitmapToMat(compareImg,img2);

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

            //matchIV.setImageBitmap(imageMatched);

            //Calculate Good matches with Lowe's ratio to distinguish and limit unnecessary match points
            LinkedList<DMatch> good_matches = new LinkedList<DMatch>();
            for (int i = 0; i < matchesList.size(); i++) {
                if (matchesList.get(i).distance <= (1.5 * min_dist))
                    good_matches.addLast(matchesList.get(i));
            }

            if(matchesList.size()>0 && good_matches.size()>0) {
                double matchPercent = (100 * good_matches.size()) / matchesList.size();
                //matchPerc.setText("Image Matching Percentage:\n"+matchPercent+"%");
                return matchPercent;
            }
            else{
                //matchPerc.setText("Image Matching Percentage:\n0.0%");
                return 0.0;
            }

//        Bitmap res1 = BitmapFactory.decodeResource(this.getResources(),R.drawable.husky1);
//        Bitmap res2 = BitmapFactory.decodeResource(this.getResources(),R.drawable.husky3);
//        Utils.bitmapToMat(res1,img1);
//        Utils.bitmapToMat(res2,img2);
//        Imgproc.cvtColor(img1,img1,Imgproc.COLOR_RGB2GRAY);
//        Imgproc.cvtColor(img2,img2,Imgproc.COLOR_RGB2GRAY);

    }

    //Function to Display Result after last comparison
    private void displayResult(){
        //Set view values
        loading.setVisibility(View.GONE);
        date.setText(highestPet.getString("foundDate"));
        matchPerc.setText("Match Found with Percentage of "+String.format("%.2f", highestMatch)+" %");

        //Load final result Image View
        Glide.with(OpenCVActivity.this).load(highestPet.getString("url")).listener(new RequestListener<Drawable>() {
            @Override
            public boolean onLoadFailed(@Nullable GlideException e, Object model, Target<Drawable> target, boolean isFirstResource) {
                Toast.makeText(OpenCVActivity.this,"Image load failed! Exception: "+e.toString(),Toast.LENGTH_SHORT).show();
                return false;
            }
            @Override
            public boolean onResourceReady(Drawable resource, Object model, Target<Drawable> target, DataSource dataSource, boolean isFirstResource) {
                pb.setVisibility(View.GONE);
                return false;
            }
        }).into(matchIV);

        //Get Post Owner Name from database
        FirebaseFirestore.getInstance().collection("User").document(highestPet.getString("postOwner")).get()
                .addOnCompleteListener(new OnCompleteListener<DocumentSnapshot>() {
                    @Override
                    public void onComplete(@NonNull Task<DocumentSnapshot> task) {
                        if(task.isSuccessful()){
                            contact.setEnabled(true);
                            contact.setText("View Contact of "+task.getResult().getString("name"));
                            contact.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View v) {
                                    //Set layout values for dialog box
                                    ScrollView sv = new ScrollView(OpenCVActivity.this);
                                    LinearLayout ll = new LinearLayout(OpenCVActivity.this);
                                    ll.setOrientation(LinearLayout.VERTICAL);
                                    ll.setGravity(Gravity.CENTER);
                                    ll.setPadding(32,32,32,32);

                                    TextView nameTV = new TextView(OpenCVActivity.this);
                                    nameTV.setTextColor(Color.parseColor("#263238"));
                                    nameTV.setTypeface(ResourcesCompat.getFont(OpenCVActivity.this,R.font.baloo));
                                    nameTV.setText("Name: "+task.getResult().getString("name"));
                                    nameTV.setTextSize(16);
                                    nameTV.setPadding(36,32,36,32);

                                    TextView hpTV = new TextView(OpenCVActivity.this);
                                    hpTV.setTextColor(Color.parseColor("#263238"));
                                    hpTV.setTypeface(ResourcesCompat.getFont(OpenCVActivity.this,R.font.baloo));
                                    hpTV.setText("Contact No.: "+task.getResult().getString("hp"));
                                    hpTV.setTextSize(16);
                                    hpTV.setPadding(36,32,36,32);

                                    ll.addView(nameTV);
                                    ll.addView(hpTV);
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

}