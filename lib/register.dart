import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pawsearch/firebase/auth.dart';

import 'firebase/database.dart';

//REGISTER BUTTON
class RegisterButton extends StatelessWidget {
  const RegisterButton({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      onPressed: () {
        Scaffold.of(context).showBottomSheet((context) => RegisterSheet());
      },
      shape: RoundedRectangleBorder(
          borderRadius: new BorderRadius.circular(18.0),
          side: BorderSide(color: Colors.black)),
      child: Text(
        'Register',
      ),
    );
  }
}

//REGISTER SHEET
class RegisterSheet extends StatefulWidget {
  RegisterSheet({
    Key key,
  }) : super(key: key);

  @override
  _RegisterSheetState createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  final FireAuth _auth = FireAuth();

  TextEditingController nameController = new TextEditingController();
  TextEditingController phoneController = new TextEditingController();
  FocusNode hpNode = new FocusNode();

  String _countryCode = "+60";
  String _verificationCode = "Empty";

  //Variable to track if it's on cooldown
  bool cooldown = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
                blurRadius: 20, color: Colors.blueGrey[900], spreadRadius: 5)
          ]),
      child: Form(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Center(
                child: Text(
                  "Register",
                  style: TextStyle(
                      color: Colors.blueGrey[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 28),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextFormField(
                controller: nameController,
                obscureText: false,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.account_circle,
                      color: Colors.blueGrey[900],
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    labelText: "Name",
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueGrey[900]),
                        borderRadius: BorderRadius.circular(32.0))),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(hpNode);
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: FittedBox(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * 0.15,
                      child: CountryCodePicker(
                        onChanged: (cc) {
                          setState(() {
                            _countryCode = cc.toString();
                          });
                        },
                        initialSelection: '+60',
                        showFlag: false,
                        showFlagDialog: true,
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      child: TextFormField(
                        focusNode: hpNode,
                        controller: phoneController,
                        style: TextStyle(color: Colors.blueGrey[900]),
                        obscureText: false,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                            icon: Icon(
                              Icons.phone_android,
                              color: Colors.blueGrey[900],
                            ),
                            contentPadding:
                                EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                            labelText: "Phone No.",
                            hintStyle: TextStyle(color: Colors.blueGrey[900]),
                            enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.blueGrey[900]),
                                borderRadius: BorderRadius.circular(32.0))),
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 30.0, left: 5.0, right: 5.0),
              child: ButtonTheme(
                  minWidth: MediaQuery.of(context).size.width * 0.98,
                  child: RaisedButton.icon(
                    icon: Icon(Icons.phone, color: Colors.white),
                    onPressed: () async {
                      //Did not pass fields verification, show dialog
                      if (phoneController.text.length < 1 ||
                          nameController.text.length < 1) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20.0))),
                              title: new Text("Register Failed!",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              content: new Text(
                                  "Please make sure every field is filled!",
                                  style: TextStyle(color: Colors.redAccent)),
                              actions: <Widget>[
                                new FlatButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: new Text("OK"))
                              ],
                            );
                          },
                        );
                      }
                      //pass field verification
                      else {
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
                                      borderRadius:
                                          BorderRadius.circular(20.0)),
                                  title: Text("Please wait"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          "Sending Verification Code to Phone Number..."),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                            child: Image.asset(
                                                "assets/images/loading.gif")),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            });
                        //Conduct registration with Firebase Phone Auth
                        registerUser(nameController.text.toString(),
                            _countryCode + phoneController.text.toString());
                      }
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(18.0),
                        side: BorderSide(color: Colors.blueGrey[900])),
                    label: Text(
                      'Register',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    color: Colors.blueGrey[900],
                  )),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5.0, right: 5.0),
              child: ButtonTheme(
                  minWidth: MediaQuery.of(context).size.width * 0.98,
                  child: RaisedButton.icon(
                    icon: Icon(Icons.cancel, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: new BorderRadius.circular(18.0),
                    ),
                    label: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    color: Colors.redAccent,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  _veriComplete(AuthCredential credential, String name, String hp) async {
    Navigator.pop(context);
    bool error = false;
    String errorMsg = "";
    await FirebaseAuth.instance
        .signInWithCredential(credential)
        .then((value) async {
      if (value.user != null) {
        //Check if user exist in database before registering
        DocumentSnapshot userInDB = await Firestore.instance
            .collection("User")
            .document(value.user.uid.toString())
            .get();
        //If user not exist in database only register user
        if (!userInDB.exists) {
          String addToDB = await Database(value.user.uid).setUser(name, hp);
          //On DB side error
          if (addToDB != "OK") {
            error = true;
            errorMsg = addToDB;
          }
        }
        //If user already exist
        else {
          error = true;
          errorMsg = "User already Exist! Please Login to Continue";
          await FireAuth().signOutUser();
        }
      } else {
        error = true;
        errorMsg = "Sign In Failed! No User Found after Sign up!";
      }
    }).catchError((onError) {
      error = true;
      errorMsg = onError.toString();
    });
    //show error message
    if (error) {
      Fluttertoast.showToast(
          msg: "Registration Failed! Reason: " + errorMsg,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG);
    }
  }

  _veriFailed(AuthException exception) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20.0))),
          title: new Text(
            "Verification Code Not Sent",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: new Text(
            "Please fill in a valid Hp Number or Check your Internet Connection",
            style: TextStyle(
              color: Colors.redAccent,
            ),
          ),
          actions: <Widget>[
            new FlatButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: new Text("OK"))
          ],
        );
      },
    );
  }

  _onCodeSent(String verificationCode, List<int> code, String name, String hp) {
    Navigator.pop(context);
    _verificationCode = verificationCode;

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          TextEditingController vcController = new TextEditingController();
          return StatefulBuilder(builder: (context, _setStateTime) {
            return WillPopScope(
              onWillPop: () async {
                _setStateTime(() {
                  cooldown = false;
                });
                return true;
              },
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0)),
                title: Text("Verification Code Sent"),
                content: TextField(
                  controller: vcController,
                  decoration:
                      InputDecoration(labelText: "Enter Verification Code"),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
                actions: <Widget>[
                  FlatButton(
                    child: Text(
                      "Verify",
                      style: TextStyle(color: Colors.blue),
                    ),
                    onPressed: () async {
                      //Conduct field verification first
                      if (vcController.text.toString().length < 1) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20.0))),
                              title: new Text(
                                "Verification Failed",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              content: new Text(
                                "Please fill in the code!",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                ),
                              ),
                              actions: <Widget>[
                                new FlatButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: new Text("OK")),
                              ],
                            );
                          },
                        );
                      }

                      //Pass field validation
                      else {
                        AuthCredential _credential =
                            await PhoneAuthProvider.getCredential(
                                verificationId: _verificationCode,
                                smsCode: vcController.text.toString());
                        await FirebaseAuth.instance
                            .signInWithCredential(_credential)
                            .catchError((onError) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(20.0))),
                                title: new Text(
                                  "Verification Failed",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                content: new Text(
                                  onError.toString(),
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                actions: <Widget>[
                                  new FlatButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: new Text("OK"))
                                ],
                              );
                            },
                          );
                        });
                      }
                    },
                  ),
                  FlatButton(
                    child: cooldown
                        ? FittedBox(child: Text("Resent"))
                        : FittedBox(child: Text("Resend")),
                    onPressed: cooldown
                        ? null
                        : () async {
                            //Start timer
                            _setStateTime(() {
                              cooldown = true;
                            });
                            //Send Verification Code Function
                            await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: hp,
                                timeout: Duration(seconds: 30),
                                verificationCompleted: (authCredential) =>
                                    _veriComplete(authCredential, name, hp),
                                verificationFailed: (authException) =>
                                    _veriFailed(authException),
                                codeSent: (verificationId, [code]) =>
                                    _onCodeSent(
                                        verificationId, [code], name, hp),
                                codeAutoRetrievalTimeout:
                                    (verificationId, [code]) => _onCodeSent(
                                        verificationId, [code], name, hp));

                            _setStateTime(() {
                              cooldown = true;
                            });
                          },
                  )
                ],
              ),
            );
          });
        });
  }

  //Register
  registerUser(String name, String hp) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: hp,
        timeout: Duration(seconds: 30),
        verificationCompleted: (authCredential) =>
            _veriComplete(authCredential, name, hp),
        verificationFailed: (authException) => _veriFailed(authException),
        codeSent: (verificationId, [code]) =>
            _onCodeSent(verificationId, [code], name, hp),
        codeAutoRetrievalTimeout: (verificationId, [code]) =>
            _onCodeSent(verificationId, [code], name, hp));
  }
}
