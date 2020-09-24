import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

class Home extends StatefulWidget {
  @override
  _State createState() => _State();
}

class _State extends State<Home> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  bool imgSelected = false;
  String loadingMsg = "Loading Model...";
  double highestConf = 0;
  var result;

  File _image;
  final picker = ImagePicker();

  List _recognitions;
  double _imageWidth;
  double _imageHeight;

  File croppedImg;

  @override
  void initState() {
    super.initState();
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(msg + "...Please wait..."),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Center(
                      child: SpinKitPouringHourglass(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        });
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

    //TODO:Remove unwanted classifications, Add second processing here (OPENCV)
    var recognitions = await Tflite.runModelOnImage(
        path: _image.path, // required
        imageMean: 0.0, // defaults to 117.0
        imageStd: 255.0, // defaults to 1.0
        threshold: 1 / 24, // defaults to 0.1
        asynch: true // defaults to true
        );

    //Post-processing 3
    recognitions.forEach((element) {
      if (element["confidence"] > highestConf) {
        highestConf = element["confidence"];
        result = element;
      }
    });

    print("First run whole results: " + recognitions.toString());
    //First result with first model
    print("First highest result " + result["label"]);

    //print overall highest result
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        "This is a " + result["label"],
        textAlign: TextAlign.center,
      ),
    ));

    //Close dialog box on getting result
    Navigator.pop(context);

    //Set back highest confidence to 0.0 for next comparison starting frm default
    highestConf = 0.0;

    //Close and release Tensorflow Lite
    await Tflite.close();
  }

  //Function to selectable display boxes on the predicted object locations on the image
  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    //Post-process 2 (Obj Det)
    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;
    MaterialColor objectColor;
    //Show Boxes on Locations of Filtered Objects and categorize with colors
    return _recognitions.map((re) {
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
      }
      else if(re["detectedClass"]=="person"){
        objectColor = Colors.yellow;
      }
      else{
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
              showLoadingDialog(context, "Cropping Image");
              //Conduct Image Cropping on Box Select
              croppedImg = await FlutterNativeImage.cropImage(
                  _image.path,
                  (re["rect"]["x"] * _imageWidth).floor(),
                  (re["rect"]["y"] * _imageHeight).floor(),
                  (re["rect"]["w"] * _imageWidth).floor(),
                  (re["rect"]["h"] * _imageHeight).floor());
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
                                  onPressed: () {
                                    setState(() {
                                      _image = croppedImg;
                                    });
                                    Navigator.pop(context1);
                                    //TODO:Next Image Processing
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
      _recognitions = tempResults;
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
                _recognitions.length < 1
                    ? "No Object have been detected in the image...\nYou may choose to proceed with the whole image..."
                    : _recognitions.length > 1
                        ? "Multiple Objects have been detected. \nTap on the box on the image to select the pet for searching."
                        : "An Object is detected on the image. \nSelect on the box to crop the image or Proceed with the whole image.",
                textAlign: TextAlign.center,
              ),
            ),
            RaisedButton.icon(
              onPressed: () {},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
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
                        ? Image.asset(
                            "assets/images/gallery.png",
                          )
                        : FadeInImage(
                            placeholder:
                                Image.asset("assets/images/loading.gif").image,
                            image: Image.file(_image).image,
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
                              ? TextStyle(color: Theme.of(context).primaryColor)
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
                                    // findType(context);
                                    showLoadingDialog(
                                        context, "Processing Image");
                                    await predictLocation(_image);
                                    Navigator.pop(context);
                                    Scaffold.of(context).showBottomSheet(
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
                    imgSelected
                        ? RaisedButton(
                            child:
                                Text("Classification Without Image Processing"),
                            onPressed: () {
                              findType(context);
                            },
                          )
                        : Container()
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
