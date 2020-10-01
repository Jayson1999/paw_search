import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawsearch/loading.dart';
import 'package:pawsearch/user.dart';
import 'package:tflite/tflite.dart';

import 'firebase/auth.dart';

class Home extends StatefulWidget {
  @override
  _State createState() => _State();
}

class _State extends State<Home> {
  //Global Variables
  FireAuth _auth = FireAuth();
  User _user = new User();
  Future getUser;
  String type = "lost";

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<
      ScaffoldState>(); //Scaffold key to show Scaffold widgets of Bottom Sheet and SnackBar

  bool imgSelected = false; //Track if any image is selected for UI changes
  String loadingMsg = "Loading Model..."; //Global reusable Loading Message

  File _image; //Track and Update Image for Searching
  final picker = ImagePicker();

  List _detections; //Object Detection needed variables
  double _imageWidth;
  double _imageHeight;
  File croppedImg;

  @override
  void initState() {
    super.initState();
    getUser = checkUser(); //Initialize checking during startup
  }

  //function to check for validated user
  checkUser() async {
    await _auth.getCurrentUser().then((value) async {
      await Firestore.instance
          .collection("User")
          .document(value.uid.toString())
          .get()
          .then((_value) {
        if (_value.data == null) {
          showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  title: Row(
                    children: <Widget>[
                      Icon(
                        Icons.cancel,
                        color: Colors.redAccent,
                      ),
                      Text(" No Account Found!"),
                    ],
                  ),
                  content: Text(
                    "Please REGISTER before logging in!",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  actions: <Widget>[
                    FlatButton(
                      child: Text("Ok"),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    )
                  ],
                );
              });

          //Sign Out false user without register at first
          _auth.signOutUser();
        } else {
          _user.name = _value.data["name"];
          _user.hp = _value.data["hp"];
          print(_user.name);
          print(_user.hp);
        }
      });
    });
    return true;
  }

  //Main build function
  @override
  Widget build(BuildContext context) {
    //Listen for check user validation before loading widgets
    return FutureBuilder(
      future: getUser,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return WillPopScope(
            onWillPop: exitDialog,
            child: Scaffold(
                key: _scaffoldKey,
                appBar: AppBar(
                  leading: Center(
                    child: CircleAvatar(
                      backgroundImage: AssetImage("assets/images/pawslogo.png"),
                    ),
                  ),
                  title: Text(
                    "Welcome " + _user.name + "!",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  centerTitle: true,
                ),
                body: Builder(
                  builder: (context) => Container(
                    height: MediaQuery.of(context).size.height,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            !imgSelected
                                ? Container()
                                : Center(
                                    child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      "Selected Image: ",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24),
                                    ),
                                  )),
                            !imgSelected
                                ? Image.asset(
                                    "assets/images/gallery.png",
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: FadeInImage(
                                      placeholder: Image.asset(
                                              "assets/images/loading.gif")
                                          .image,
                                      image: Image.file(_image).image,
                                    ),
                                  ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: imgSelected
                                  ? Container()
                                  : Text(
                                      "Select an Image of Your Pet for Pet Searching",
                                      style: TextStyle(fontSize: 26),
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                            RaisedButton.icon(
                                onPressed: () {
                                  getImage();
                                },
                                elevation: 6,
                                color: imgSelected
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                icon: imgSelected
                                    ? Icon(
                                        Icons.image,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : Icon(
                                        Icons.image,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  "Upload from Gallery",
                                  style: imgSelected
                                      ? TextStyle(
                                          color: Theme.of(context).primaryColor)
                                      : TextStyle(color: Colors.white),
                                )),
                            imgSelected
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8.0, right: 8.0, top: 20),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width,
                                      child: RaisedButton.icon(
                                          onPressed: () async {
                                            showLoadingDialog(
                                                context, "Processing Image");
                                            await predictLocation(
                                                _image); //Conduct Object Detection
                                            Navigator.pop(context);
                                            //Display Object Detections in Bottom Sheet
                                            _scaffoldKey.currentState
                                                .showBottomSheet(
                                                    (context) => searchSheet());
                                          },
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20.0)),
                                          elevation: 6,
                                          color: Theme.of(context).primaryColor,
                                          icon: Icon(
                                            Icons.search,
                                            color: Colors.white,
                                          ),
                                          label: Text("Begin Search",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ))),
                                    ),
                                  )
                                : Container(),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
          );
        } else {
          return Loading();
        }
      },
    );
  }

  //Function to pick image from gallery
  Future getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    setState(() {
      _image = File(pickedFile.path);
      imgSelected = true;
    });
  }

  //Function to show Loading Dialog
  showLoadingDialog(BuildContext context, String msg) {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async {
              return await false;
            },
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)),
              elevation: 10,
              title: Text("Loading..."),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(msg + "...Please wait..."),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                          child: Image.asset("assets/images/loading.gif")),
                    )
                  ],
                ),
              ),
            ),
          );
        });
  }

  //Function to detect objects' location in the image
  predictLocation(File image) async {
    //Check if there's image before conducting function operation
    if (image == null) return;

    //Load Object Detection model
    await Tflite.loadModel(
        model: "assets/model/ssd_mobilenet.tflite",
        labels: "assets/model/ssd_mobilenet.txt");

    //Conduct Object Detection on Image
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path, numResultsPerClass: 1);

    print("Before: " + recognitions.toString());

    //Temporary store results map as List to allow removing of elements
    var tempResults = new List.from(recognitions);

    //Post-processing 1 (Obj Det)
    double highestPerc = 0;
    var highestItem;
    int counter = 0;
    //Remove object prediction with lower than 50% confidence, if none, get the highest conf only
    recognitions.forEach((element) {
      counter++;
      if (element["confidenceInClass"] > highestPerc) {
        highestPerc = element["confidenceInClass"];
        highestItem = element;
      }
      if (element["confidenceInClass"] < 0.5) {
        tempResults.remove(element);
      }
      if (counter == recognitions.length && tempResults.isEmpty) {
        tempResults.add(highestItem);
      }
    });

    print("After: " + tempResults.toString());

    //Set global recognition with results and make changes on state
    setState(() {
      _detections = tempResults;
    });

    //Set global image resolution
    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool b) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
          });
        })));
  }

  //Function to display selectable boxes on the predicted object locations on the image
  List<Widget> renderBoxes(Size screen) {
    if (_detections == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    //Post-process 2 (Obj Det)
    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;
    MaterialColor objectColor;
    //Show Boxes on Locations of Filtered Objects and categorize with colors
    return _detections.map((re) {
      if (re["detectedClass"] == "bird" ||
          re["detectedClass"] == "cat" ||
          re["detectedClass"] == "dog" ||
          re["detectedClass"] == "horse" ||
          re["detectedClass"] == "sheep" ||
          re["detectedClass"] == "cow" ||
          re["detectedClass"] == "elephant" ||
          re["detectedClass"] == "bear" ||
          re["detectedClass"] == "zebra" ||
          re["detectedClass"] == "giraffe" ||
          re["detectedClass"] == "teddy bear") {
        objectColor = Colors.green;
      } else if (re["detectedClass"] == "person") {
        objectColor = Colors.yellow;
      } else {
        objectColor = Colors.red;
      }
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
            color: objectColor,
            width: 3,
          )),
          child: FlatButton(
            color: Colors.transparent,
            onPressed: () async {
              showLoadingDialog(context, "Processing & Cropping Image");
              //Conduct Image Cropping on Box Select
              croppedImg = await FlutterNativeImage.cropImage(
                      _image.path,
                      (re["rect"]["x"] * _imageWidth).floor(),
                      (re["rect"]["y"] * _imageHeight).floor(),
                      (re["rect"]["w"] * _imageWidth).floor(),
                      (re["rect"]["h"] * _imageHeight).floor())
                  .catchError((onError) {
                Navigator.pop(context);
                print("Crop Failed! Rect not found! " + onError.toString());
              });
              Navigator.pop(context);

              showDialog(
                  context: context,
                  builder: (BuildContext context1) {
                    return AlertDialog(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0)),
                      title: Row(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.crop),
                          ),
                          Text(
                            "Cropped Image: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            FadeInImage(
                              placeholder:
                                  Image.asset("assets/images/loading.gif")
                                      .image,
                              image: Image.file(croppedImg).image,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 15.0),
                              child: Container(
                                width: MediaQuery.of(context1).size.width,
                                child: RaisedButton.icon(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10.0)),
                                  onPressed: () async {
                                    setState(() {
                                      _image = croppedImg;
                                    });
                                    Navigator.pop(context1);
                                    Navigator.pop(context);
                                    //Conduct Image Classification on Cropped Image
                                    findType(context);
                                  },
                                  icon: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    "Proceed",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            FlatButton.icon(
                              onPressed: () {
                                Navigator.pop(context1);
                              },
                              icon: Icon(
                                Icons.cancel,
                                color: Colors.redAccent,
                              ),
                              label: Text(
                                "Cancel",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              color: Colors.white,
                            )
                          ],
                        ),
                      ),
                    );
                  });
            },
          ),
        ),
      );
    }).toList();
  }

  //Function to return the widget for the bottom sheet
  Widget searchSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              blurRadius: 15, color: Colors.blueGrey[900], spreadRadius: 1)
        ],
      ),
      height: MediaQuery.of(context).size.height * 0.95,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Center(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Pet Image",
                style: TextStyle(fontSize: 20),
              ),
            )),
            Center(
              child: Stack(
                children: <Widget>[
                  Image.file(_image),
                ]..addAll(renderBoxes(MediaQuery.of(context).size)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text(
                _detections.length < 1
                    ? "No Object have been detected in the image...\nYou may choose to proceed with the whole image..."
                    : _detections.length > 1
                        ? "Multiple Objects have been detected. \nTap on the box on the image to select the pet for searching."
                        : "An Object is detected on the image. \nSelect on the box to crop the image or Proceed with the whole image.",
                textAlign: TextAlign.center,
              ),
            ),
            RaisedButton.icon(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context1) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0)),
                        title: Row(
                          children: <Widget>[
                            Icon(Icons.notification_important,color: Colors.amber,),
                            Text(" Reminder",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Text(
                            "Please be advised that Proceeding with the Whole Image may affect accuracy of the search. You can choose to Go Back and Select another image or Proceed Anyway"),
                        actions: <Widget>[
                          RaisedButton.icon(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0)),
                            icon: Icon(Icons.arrow_forward_ios,
                                color: Colors.white),
                            label: Text("Proceed Anyway",
                                style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              Navigator.pop(context1);
                              //Proceed Image Classification without cropping
                              findType(context);
                            },
                            color: Colors.redAccent,
                          ),
                          RaisedButton.icon(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0)),
                            icon: Icon(Icons.backspace, color: Colors.white),
                            label: Text("Go Back",
                                style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              //Cancel Image Classification and Proceed to change new image
                              Navigator.pop(context1);
                            },
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      );
                    });
              },
              icon: Icon(
                Icons.image,
                color: Colors.white,
              ),
              label: Flexible(
                child: Text(
                  "Proceed with the Whole Image",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
              color: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: FlatButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.cancel,
                  color: Colors.redAccent,
                ),
                label: Flexible(
                  child: Text(
                    "Cancel & Select Another Image",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0)),
              ),
            )
          ],
        ),
      ),
    );
  }

  //Function to conduct image classification on processed image
  findType(BuildContext context) async {
    //show loading dialog upon initializing
    showLoadingDialog(context, loadingMsg);

    //load tflite model
    String model = await Tflite.loadModel(
        model: "assets/model/pet_model.tflite",
        labels: "assets/model/pet_label.txt",
        numThreads: 1, // defaults to 1
        isAsset: true,
        useGpuDelegate: false);

    //Change loading message after models are successfully loaded
    setState(() {
      loadingMsg = "Inferencing with Models...";
    });

    //Conduct OpenCV img processing before classification
    //TODO:Remove unwanted classifications, Add second processing here (OPENCV, segmentation, threshold, compare), Create OOP Class

    var recognitions = await Tflite.runModelOnImage(
        path: _image.path, // required
        imageMean: 0.0, // defaults to 117.0
        imageStd: 255.0, // defaults to 1.0
        threshold: 1 / 24, // defaults to 0.1
        asynch: true // defaults to true
        );

    //Close loading dialog box on getting result
    Navigator.pop(context);

    var classification; //Store Classification Result
    double highestConf = 0;
    //Post-processing 3 (Remove lower than 50% confidence classification)
    recognitions.forEach((element) {
      if (element["confidence"] > highestConf && element["confidence"] > 0.5) {
        highestConf = element["confidence"];
        classification = element;
      }
    });

    //When Class found
    if (classification != null) {
      //First result with first model
      print("Whole results: " + recognitions.toString());
      print("Highest result " + classification["label"]);

      //Remove Labelling number and Empty space in front
      String breed = classification["label"]
          .toString()
          .replaceAll(RegExp(r'\d+'), "")
          .trimLeft();

      //Show dialog with filtered class & ask for option before proceeding to OpenCV module
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: <Widget>[Icon(Icons.adb,color: Colors.greenAccent,), Text(" Detected Class: ")],
              ),
              content: Text(breed +
                  " detected with " +
                  (classification["confidence"] * 100).toStringAsFixed(2) +
                  "% confidence."),
              actions: <Widget>[
                FlatButton.icon(
                    onPressed: () {
                      _getOpenCVResult(breed);
                    },
                    icon: Icon(Icons.arrow_forward_ios),
                    label: Text(
                      "Search for Pet",
                      style: TextStyle(color: Colors.blue),
                    )),
                FlatButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.cancel, color: Colors.redAccent),
                    label: Text(
                      "Cancel",
                      style: TextStyle(color: Colors.red),
                    )),
              ],
            );
          });
    }

    //If no class-match found
    else {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
        content: Text(
          "Are you sure this is a pet image?\n We could not find any related breed on the image...Maybe try another pet image.",
          textAlign: TextAlign.center,
        ),
      ));
    }

    //Close and release Tensorflow Lite after Classification
    await Tflite.close();
  }

  //Function to invoke Android's OpenCV method from Android platform
  Future<void> _getOpenCVResult(String breed) async {
    try {
      //Pass search type, breed, image while invoking method
      await MethodChannel("openCVChannel").invokeMethod('opencvComparison',
          {"breed": breed, "type": type, "imageSrc": _image.toString()});
    } on PlatformException catch (e) {
      print("Failed to get opencv result: '${e.message}'.");
    }
  }

  //Function to exit app through dialog
  Future<bool> exitDialog() async {
    return await (showDialog(
          context: context,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async {
                return true;
              },
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20.0))),
                title: Row(
                  children: <Widget>[
                    Container(
                      child: Image.asset(
                        "assets/images/exit.png",
                        color: Colors.redAccent,
                      ),
                      width: 50,
                      height: 50,
                    ),
                    new Text("Exit ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text("Exit Application?"),
                actions: <Widget>[
                  FlatButton(
                    child: Text("Yes"),
                    onPressed: () {
                      SystemChannels.platform
                          .invokeMethod('SystemNavigator.pop');
                    },
                  ),
                  FlatButton(
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
            );
          },
        )) ??
        false;
  }
}
