package com.fyp.pawsearch;


import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.util.Log;
import android.widget.ImageView;
import android.widget.TextView;

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
import org.opencv.imgproc.Imgproc;

import java.io.IOException;
import java.util.LinkedList;
import java.util.List;


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
    private Dialog dialog;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_open_c_v);

        //initialize view
        matchIV = (ImageView) findViewById(R.id.matchIV);
        matchPerc = (TextView) findViewById(R.id.matchPerc);

        //show loading box
        dialog = new Dialog(OpenCVActivity.this);
        AlertDialog.Builder builder = new AlertDialog.Builder(OpenCVActivity.this);
        builder.setTitle("Loading")
                .setMessage("Please wait while OpenCV loads up")
                .setCancelable(false);
        dialog = builder.create();
        dialog.show();

        //Check opencv loading status
        if(!OpenCVLoader.initDebug()){
            Log.i("info","Failed to load OpenCV during startup");
        }
        else{
            //only initialize openCV after it is successfully loaded
            descriptor = ORB.create();
            detector = ORB.create();
            matcher = DescriptorMatcher.create(DescriptorMatcher.BRUTEFORCE_HAMMING);
            img1 = new Mat();
            img2 = new Mat();
            descriptors1 = new Mat();
            descriptors2 = new Mat();
            matOfKeyPoint1 = new MatOfKeyPoint();
            matOfKeyPoint2 = new MatOfKeyPoint();
            dialog.dismiss();
            startComparison();
        }

    }

    //handle async callback of loading opencv
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

    private BaseLoaderCallback mLoaderCallback = new BaseLoaderCallback(this) {
        @Override
        public void onManagerConnected(int status) {
            switch (status) {
                case LoaderCallbackInterface.SUCCESS: {
                    Log.i("TAG", "OpenCV loaded successfully");
                    try {
                        initializesOpenCV();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
                break;
                default: {
                    super.onManagerConnected(status);
                }
                break;
            }
        }
    };

    //conduct image comparisons
    private void startComparison(){
        Bitmap res1 = BitmapFactory.decodeResource(this.getResources(),R.drawable.husky1);
        Bitmap res2 = BitmapFactory.decodeResource(this.getResources(),R.drawable.husky3);
        Utils.bitmapToMat(res1,img1);
        Utils.bitmapToMat(res2,img2);
//        Imgproc.cvtColor(img1,img1,Imgproc.COLOR_RGB2GRAY);
//        Imgproc.cvtColor(img2,img2,Imgproc.COLOR_RGB2GRAY);

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
        Bitmap imageMatched = Bitmap.createBitmap(outputImg.cols(), outputImg.rows(), Bitmap.Config.RGB_565);//need to save bitmap
        Utils.matToBitmap(outputImg, imageMatched);

        matchIV.setImageBitmap(imageMatched);

        //Calculate Good matches with Lowe's ratio to distinguish and limit unnecessary match points
        LinkedList<DMatch> good_matches = new LinkedList<DMatch>();
        for (int i = 0; i < matchesList.size(); i++) {
            if (matchesList.get(i).distance <= (1.5 * min_dist))
                good_matches.addLast(matchesList.get(i));
        }

        if(matchesList.size()>0 && good_matches.size()>0) {
            double matchPercent = (100 * good_matches.size()) / matchesList.size();
            matchPerc.setText("Image Matching Percentage:\n"+matchPercent+"%");
        }
        else{
            matchPerc.setText("Image Matching Percentage:\n0.0%");
        }

    }

    private void initializesOpenCV() throws IOException{
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

}