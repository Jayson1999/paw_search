import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawsearch/loading.dart';
import 'package:pawsearch/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Future<List> getPosts;
  String type;
  SharedPreferences pref;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<
      ScaffoldState>(); //Scaffold key to show Scaffold widgets of Bottom Sheet and SnackBar

  final GlobalKey _imgKey = GlobalKey();

  ScrollController _scrollController;
  bool postSelected = false;
  bool profSelected = false; //Track if profile is clicked
  bool imgSelected = false; //Track if any image is selected for UI changes
  String loadingMsg = "Loading Model..."; //Global reusable Loading Message

  File _image; //Track and Update Image for Searching
  final picker = ImagePicker();

  List _detections; //Object Detection needed variables
  double _imageWidth;
  double _imageHeight;
  File croppedImg;
  bool cropBoxChanged = false;
  //New variables to store new positions if crop box changed
  double newBoxLeft;
  double newBoxTop;
  double newBoxWidth;
  double newBoxHeight;
  int newCropLeft;
  int newCropTop;
  int newCropWidth;
  int newCropHeight;

  @override
  void initState() {
    super.initState();
    getUser = checkUser(); //Initialize checking during startup
    getPosts = userPosts(); //Get all the post of the user
    _scrollController = new ScrollController();
    //Listen to Scrolling, collapse Profile on scroll
    _scrollController.addListener(() {
      if (_scrollController.offset >=
              _scrollController.position.minScrollExtent &&
          !_scrollController.position.outOfRange) {
        setState(() {
          profSelected = false;
          postSelected = false;
        });
      }
    });
  }

  //function to check for validated user
  checkUser() async {
    await _auth.getCurrentUser().then((value) async {
      await Firestore.instance
          .collection("User")
          .document(value.uid.toString())
          .get()
          .then((_value) async {
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
          //Sign in User and write UID to SharedPreferences
          pref = await SharedPreferences.getInstance();
          pref.setString("uid", value.uid.toString());
          _user.name = _value.data["name"];
          _user.hp = _value.data["hp"];
          print(_user.name);
          print(_user.hp);
        }
      });
    });
    return true;
  }

  Future<List> userPosts() async {
    pref = await SharedPreferences.getInstance();
    List posts = new List();
    //Get from Found Posts
    await Firestore.instance
        .collection("Found")
        .where("postOwner", isEqualTo: pref.getString("uid"))
        .getDocuments()
        .then((value) {
      value.documents.forEach((element) {
        posts.add(element);
      });
    });
    //Get from Lost Posts
    await Firestore.instance
        .collection("Lost")
        .where("postOwner", isEqualTo: pref.getString("uid"))
        .getDocuments()
        .then((value) {
      value.documents.forEach((element) {
        posts.add(element);
      });
    });
    return posts;
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
                backgroundColor: Colors.white,
                key: _scaffoldKey,
                appBar: AppBar(
                  leading: InkWell(
                    onTap: () {
                      setState(() {
                        if (postSelected) {
                          postSelected = false;
                          profSelected = false;
                        } else {
                          getPosts =
                              userPosts(); //Reload new results each time it's clicked
                          postSelected = true;
                          profSelected = false;
                        }
                      });
                    },
                    child: Center(
                      child: CircleAvatar(
                        backgroundImage:
                            AssetImage("assets/images/pawslogo.png"),
                      ),
                    ),
                  ),
                  actions: <Widget>[
                    IconButton(
                      icon: Icon(
                        !profSelected
                            ? Icons.account_circle
                            : Icons.keyboard_arrow_up,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (profSelected) {
                            profSelected = false;
                            postSelected = false;
                          } else {
                            profSelected = true;
                            postSelected = false;
                          }
                        });
                      },
                    )
                  ],
                  title: Text(
                    !profSelected && !postSelected
                        ? "Welcome " + _user.name + "!"
                        : postSelected ? "Your Reports" : "Profile",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  centerTitle: true,
                ),
                body: Builder(
                  builder: (context) => Container(
                    height: MediaQuery.of(context).size.height,
                    child: Center(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            //Expandable layout to display Profile or show user's Posts
                            showProfile(),
                            showPosts(),
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
                              padding: EdgeInsets.all(imgSelected ? 8 : 20.0),
                              child: imgSelected
                                  ? Container()
                                  : Text(
                                      "Select an Image of The Pet for Pet Searching",
                                      style: TextStyle(fontSize: 24),
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
                            RaisedButton.icon(
                                onPressed: () {
                                  getFromCam();
                                },
                                elevation: 6,
                                color: imgSelected
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                icon: imgSelected
                                    ? Icon(
                                        Icons.camera_alt,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  "Take from Camera",
                                  style: imgSelected
                                      ? TextStyle(
                                          color: Theme.of(context).primaryColor)
                                      : TextStyle(color: Colors.white),
                                )),
                            imgSelected
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8.0,
                                        right: 8.0,
                                        top: 15,
                                        bottom: 28),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width,
                                      child: RaisedButton.icon(
                                          onPressed: () {
                                            //Select Search Type Option before proceeding
                                            showDialog(
                                                barrierDismissible: false,
                                                context: context,
                                                builder: (BuildContext
                                                    innerContext) {
                                                  return AlertDialog(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20)),
                                                    title: Row(
                                                      children: <Widget>[
                                                        ImageIcon(Image.asset(
                                                                "assets/images/pawslogoflattened.png")
                                                            .image),
                                                        Text(
                                                            " Select an Option")
                                                      ],
                                                    ),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: <Widget>[
                                                          Text(
                                                              "The app will conduct search on the database before allowing to file a new report on both functions."),
                                                          Container(
                                                            width: 150,
                                                            child: FittedBox(
                                                              child:
                                                                  RaisedButton
                                                                      .icon(
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            20)),
                                                                icon: Icon(
                                                                  Icons.search,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                label: Text(
                                                                  "I Lost a Pet",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .justify,
                                                                ),
                                                                color: Theme.of(
                                                                        context)
                                                                    .primaryColor,
                                                                onPressed:
                                                                    () async {
                                                                  type = "lost";
                                                                  Navigator.pop(
                                                                      innerContext);
                                                                  showLoadingDialog(
                                                                      context,
                                                                      "Processing Image");
                                                                  await predictLocation(
                                                                      _image); //Conduct Object Detection
                                                                  Navigator.pop(
                                                                      context);
                                                                  //Display Object Detections in Bottom Sheet
                                                                  _scaffoldKey
                                                                      .currentState
                                                                      .showBottomSheet(
                                                                          (context) =>
                                                                              searchSheet());
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            width: 150,
                                                            child: FittedBox(
                                                              child:
                                                                  RaisedButton
                                                                      .icon(
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            20)),
                                                                icon: Icon(
                                                                  Icons.pets,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                label: Text(
                                                                  "I Found a Pet",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                color:
                                                                    Colors.blue,
                                                                onPressed:
                                                                    () async {
                                                                  type =
                                                                      "found";
                                                                  Navigator.pop(
                                                                      innerContext);
                                                                  showLoadingDialog(
                                                                      context,
                                                                      "Processing Image");
                                                                  await predictLocation(
                                                                      _image); //Conduct Object Detection
                                                                  Navigator.pop(
                                                                      context);
                                                                  //Display Object Detections in Bottom Sheet
                                                                  _scaffoldKey
                                                                      .currentState
                                                                      .showBottomSheet(
                                                                          (context) =>
                                                                              searchSheet());
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                });
                                          },
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20.0)),
                                          elevation: 6,
                                          color: Theme.of(context).primaryColor,
                                          icon: ImageIcon(
                                            Image.asset(
                                                    "assets/images/pawslogoflattened.png")
                                                .image,
                                            color: Colors.white,
                                          ),
                                          label: Text("Begin Process",
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
                ),
              ));
        } else {
          return Loading();
        }
      },
    );
  }

  Widget showProfile() {
    return AnimatedContainer(
      color: Theme.of(context).primaryColor,
      duration: Duration(milliseconds: 250),
      width: profSelected ? MediaQuery.of(context).size.width : 0,
      height: profSelected ? 170 : 0,
      child: Container(
        height: 170,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: 8.0),
                  child: Text(
                    "Name: " + _user.name,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: 8.0),
                  child: Text(
                    "Phone No.: " + _user.hp,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: 8.0),
                  child: Text(
                    "UID: " + pref.get("uid"),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: RaisedButton.icon(
                      color: Colors.redAccent,
                      label:
                          Text("Logout", style: TextStyle(color: Colors.white)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      icon: Icon(
                        Icons.exit_to_app,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Sign Out"),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                content:
                                    Text("Are you sure you want to sign out?"),
                                actions: <Widget>[
                                  FlatButton(
                                    child: Text("Confirm",
                                        style: TextStyle(color: Colors.blue)),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await FireAuth().signOutUser();
                                    },
                                  ),
                                  FlatButton(
                                    child: Text("Cancel",
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  )
                                ],
                              );
                            });
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget showPosts() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      height: postSelected ? 500 : 0,
      child: FutureBuilder(
          future: getPosts,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data.length > 0) {
                return Container(
                  color: Theme.of(context).primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: snapshot.data.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            reunionDialog(snapshot.data.elementAt(index));
                          },
                          child: Card(
                            child: ListTile(
                              leading: ImageIcon(
                                Image.asset(
                                        "assets/images/pawslogoflattened.png")
                                    .image,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(
                                  snapshot.data.elementAt(index).documentID),
                              subtitle: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Expanded(
                                      child: Text("Report Type: " +
                                          snapshot.data
                                              .elementAt(index)
                                              .data["type"] +
                                          "\nBreed: " +
                                          snapshot.data
                                              .elementAt(index)
                                              .data["breed"] +
                                          "\nTap to set as \"Reunioned\".")),
                                  Container(
                                      width: 80,
                                      height: 80,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: CachedNetworkImage(
                                          imageUrl: snapshot.data
                                              .elementAt(index)
                                              .data["url"],
                                          progressIndicatorBuilder: (context,
                                                  url, downloadProgress) =>
                                              Center(
                                            child: CircularProgressIndicator(
                                              value: downloadProgress.progress,
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Icon(
                                            Icons.error,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ))
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              } else {
                return Center(
                    child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Text(
                    "No Reports Found! Begin the search process to file a new report.",
                    textAlign: TextAlign.center,
                  ),
                ));
              }
            } else {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset("assets/images/loading.gif"),
                ),
              );
            }
          }),
    );
  }

  //Function to set pets as Reunioned status
  reunionDialog(DocumentSnapshot snapshot) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)),
            title: Text("Set Pet as \"Reunioned\""),
            content: Text(
                "Setting this pet's status as \"Reunioned\" will automatically remove its report on the database as well. Do you confirm?"),
            actions: <Widget>[
              FlatButton.icon(
                icon: Icon(
                  Icons.done,
                  color: Colors.green,
                ),
                label: Text(
                  "Confirm",
                  style: TextStyle(color: Colors.blue),
                ),
                onPressed: () async {
                  showLoadingDialog(
                      context, "Setting Up Reunion and Clearing Report");
                  bool error =
                      false; //To track if any error occurs during deletion
                  //Get reference of cloud storage from db url
                  await FirebaseStorage.instance
                      .getReferenceFromUrl(snapshot.data["url"])
                      .then((value) {
                    value.delete().then((deleteValue) async {
                      await Firestore.instance
                          .collection("Found")
                          .document(snapshot.documentID)
                          .get()
                          .then((value) async {
                        //check if document exist in Found or Lost before deleting
                        if (value.exists) {
                          await Firestore.instance
                              .collection("Found")
                              .document(snapshot.documentID)
                              .delete();
                        }
                        //if not exist in Found
                        else {
                          await Firestore.instance
                              .collection("Lost")
                              .document(snapshot.documentID)
                              .get()
                              .then((value) async {
                            //conduct further checking in Lost before deleting
                            if (value.exists) {
                              await Firestore.instance
                                  .collection("Lost")
                                  .document(snapshot.documentID)
                                  .delete();
                            } else {
                              error = true;
                              _scaffoldKey.currentState.showSnackBar(SnackBar(
                                content: Text(
                                    "Could not find the document in database...",
                                    style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.redAccent,
                              ));
                            }
                          });
                        }
                      });
                    }).catchError((onError) {
                      error = true;
                      _scaffoldKey.currentState.showSnackBar(SnackBar(
                        content: Text(
                            "An error occurred while deleting from Cloud. Exception: " +
                                onError.toString(),
                            style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.redAccent,
                      ));
                    });
                  }).catchError((onError) {
                    error = true;
                    _scaffoldKey.currentState.showSnackBar(SnackBar(
                      content: Text(
                          "An error occured while reading Image URL. Exception: " +
                              onError.toString(),
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.redAccent,
                    ));
                  });

                  Navigator.pop(context); //Close loading dialog
                  //On success delete at all place
                  if (!error) {
                    Navigator.pop(context);
                    _scaffoldKey.currentState.showSnackBar(SnackBar(
                      content: Text(
                        "Congratulations on the Pet Reunion. The Report has been cleared.",
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blue,
                      behavior: SnackBarBehavior.floating,
                    ));
                    //Refresh state
                    setState(() {
                      getPosts = userPosts(); //Reload new results
                      postSelected = false;
                    });
                  }
                },
              ),
              FlatButton.icon(
                icon: Icon(
                  Icons.cancel,
                  color: Colors.redAccent,
                ),
                label: Text(
                  "Cancel",
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }

  //Function to pick image from gallery
  Future getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        imgSelected = true;
      });
    }
  }

  //Function to take image from camera
  Future getFromCam() async {
    final pickedFile = await picker.getImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        imgSelected = true;
      });
    }
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

  //The widgets inside Draggable
  Widget draggableItem(double boxWidth, double boxHeight, int cropLeft,
      int cropTop, int cropWidth, int cropHeight, MaterialColor objectColor) {
    return Container(
      width: boxWidth,
      height: boxHeight,
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
                  _image.path, cropLeft, cropTop, cropWidth, cropHeight)
              .catchError((onError) {
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
                              Image.asset("assets/images/loading.gif").image,
                          image: croppedImg != null
                              ? Image.file(croppedImg).image
                              : Image.network(
                                      "https://kajidata.com/resources/2019/02/error.jpeg")
                                  .image,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 15.0),
                          child: Container(
                            width: MediaQuery.of(context1).size.width,
                            child: RaisedButton.icon(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0)),
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
    );
  }

  //Function to display selectable boxes on the predicted object locations on the image
  List<Widget> renderBoxes(Size screen, StateSetter setInnerState) {
    if (_detections == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    //Post-process 2 (Obj Det)
    double factorX;
    double factorY;
    if (screen.width > _imageWidth) {
      //Check if screen_width allows full image width
      factorX = _imageWidth;
      factorY = _imageHeight / _imageWidth * _imageWidth;
    } else {
      factorX = screen.width;
      factorY = _imageHeight / _imageWidth * screen.width;
    }
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

      //Calculate boxes of crop
      double boxLeft = !cropBoxChanged ? re["rect"]["x"] * factorX : newBoxLeft;
      double boxTop = !cropBoxChanged ? re["rect"]["y"] * factorY : newBoxTop;
      double boxWidth =
          !cropBoxChanged ? re["rect"]["w"] * factorX : newBoxWidth;
      double boxHeight =
          !cropBoxChanged ? re["rect"]["h"] * factorY : newBoxHeight;

      //Calculate actual image crop offsets
      int cropLeft = !cropBoxChanged
          ? (re["rect"]["x"] * _imageWidth).floor()
          : newCropLeft;
      int cropTop = !cropBoxChanged
          ? (re["rect"]["y"] * _imageHeight).floor()
          : newCropTop;
      int cropWidth = !cropBoxChanged
          ? (re["rect"]["w"] * _imageWidth).floor()
          : newCropWidth;
      int cropHeight = !cropBoxChanged
          ? (re["rect"]["h"] * _imageHeight).floor()
          : newCropHeight;

      //TODO: Check on Landscape, Add Resizable
      return Positioned(
        left: boxLeft,
        top: boxTop,
        width: boxWidth,
        height: boxHeight,
        child: Draggable(
          childWhenDragging: Container(),
          child: draggableItem(boxWidth, boxHeight, cropLeft, cropTop,
              cropWidth, cropHeight, objectColor),
          feedback: draggableItem(boxWidth, boxHeight, cropLeft, cropTop,
              cropWidth, cropHeight, objectColor),
          onDragEnd: (details) {
            RenderBox renderBox = _imgKey.currentContext.findRenderObject();
            Offset _position = renderBox.globalToLocal(details.offset);

            //Validate dropped offset before setting new offset
            if (screen.width <=
                        _imageWidth && //Check if image width exceeds screen width
                    _position.dx + boxWidth <=
                        screen.width && //check x-axis's right part
                    _position.dx > 0 && //check x-axis's left part
                    _position.dy <=
                        _position.dy *
                            _imageHeight /
                            _imageWidth *
                            screen.width && //check y-axis's top part
                    _position.dy + boxHeight <=
                        _imageHeight /
                            _imageWidth *
                            screen.width //check y-axis's bottom part
                ) {
              setInnerState(() {
                newBoxLeft = _position.dx;
                newBoxTop = _position.dy;
                newBoxWidth = boxWidth;
                newBoxHeight = boxHeight;
                if (screen.width > _imageWidth) {
                  //Check if screen_width allows full image width
                  newCropLeft =
                      (_position.dx / _imageWidth * _imageWidth).floor();
                  newCropTop =
                      (_position.dy / _imageWidth * _imageWidth).floor();
                } else {
                  newCropLeft = (_position.dx / screen.width * _imageWidth)
                      .floor(); //Get the position for cropping based on screen size
                  newCropTop =
                      (_position.dy / screen.width * _imageWidth).floor();
                }
                newCropWidth = cropWidth;
                newCropHeight = cropHeight;
                cropBoxChanged = true;
              });
            }
            //If screen width exceeds image width
            else if (screen.width >
                        _imageWidth && //Check if screen size exceeds width
                    _position.dx + boxWidth <=
                        _imageWidth && //check x-axis's right part
                    _position.dx > 0 && //check x-axis's left part
                    _position.dy <=
                        _position.dy *
                            _imageHeight /
                            _imageWidth *
                            _imageWidth && //check y-axis's top part
                    _position.dy + boxHeight <=
                        _imageHeight /
                            _imageWidth *
                            _imageWidth //check y-axis's bottom part
                ) {
              setInnerState(() {
                newBoxLeft = _position.dx;
                newBoxTop = _position.dy;
                newBoxWidth = boxWidth;
                newBoxHeight = boxHeight;
                if (screen.width > _imageWidth) {
                  //Check if screen_width allows full image width
                  newCropLeft =
                      (_position.dx / _imageWidth * _imageWidth).floor();
                  newCropTop =
                      (_position.dy / _imageWidth * _imageWidth).floor();
                } else {
                  newCropLeft = (_position.dx / screen.width * _imageWidth)
                      .floor(); //Get the position for cropping based on screen size
                  newCropTop =
                      (_position.dy / screen.width * _imageWidth).floor();
                }
                newCropWidth = cropWidth;
                newCropHeight = cropHeight;
                cropBoxChanged = true;
              });
            }
          },
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
              child: StatefulBuilder(builder: (context, setInnerState) {
                return Stack(
                  children: <Widget>[
                    DragTarget(
                      builder: (context, List candidateData, rejectedData) {
                        return Image.file(
                          _image,
                          key: _imgKey,
                        );
                      },
                      onAccept: (data) {
                        return true;
                      },
                      onWillAccept: (data) {
                        return true;
                      },
                    ),
                  ]..addAll(
                      renderBoxes(MediaQuery.of(context).size, setInnerState)),
                );
              }),
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
                            Icon(
                              Icons.notification_important,
                              color: Colors.amber,
                            ),
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
                  setState(() {
                    cropBoxChanged = false;
                  });
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
    cropBoxChanged = false;
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

    //TODO:Remove unwanted classifications, set threshold value (Use Confusion Matrix)

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
    //Post-processing 3 (Get the highest Confidence & Remove lower than 50% confidence classification)
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
                children: <Widget>[
                  ImageIcon(
                    Image.asset("assets/images/pawslogoflattened.png").image,
                  ),
                  Text(" Detected Class: ")
                ],
              ),
              content: Text(breed +
                  " detected with " +
                  (classification["confidence"] * 100).toStringAsFixed(2) +
                  "% confidence."),
              actions: <Widget>[
                FlatButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _getOpenCVResult(breed);
                    },
                    icon: Icon(Icons.search),
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
      print(recognitions.toString());
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
