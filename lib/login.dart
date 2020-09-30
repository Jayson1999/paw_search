import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase/auth.dart';

//LOGIN BUTTON
class LoginButton extends StatelessWidget {
  const LoginButton({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      onPressed: () {
        Scaffold.of(context).showBottomSheet((context) => LoginSheet());
      },
      shape: RoundedRectangleBorder(
          borderRadius: new BorderRadius.circular(18.0),
          side: BorderSide(color: Colors.black)),
      child: Text(
        'Login',
        style: TextStyle(
            color: Colors.white
        ),
      ),
      color: Colors.blueGrey[900],
    );
  }
}

//LOGIN SHEET
class LoginSheet extends StatefulWidget {
  LoginSheet({
    Key key,
  }) : super(key: key);

  @override
  _LoginSheetState createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final FireAuth _auth = FireAuth();
  FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  String _smsVerificationCode = "Empty";

  TextEditingController hpController = new TextEditingController();
  TextEditingController vcController = new TextEditingController();
  String cc = "+60";
  FocusNode vcNode = new FocusNode();
  bool hpDone = false;
  bool vcDone = false;
  //Variable to track if it's on timer cooldown
  bool cooldown = false;
  int numTimer = 30;
  Timer _timer;


  _sendPhoneVeri() async {
    _verificationComplete(AuthCredential authCredential) async{
      await _firebaseAuth.signInWithCredential(authCredential);
    }

    _verificationFailed(AuthException authException) {
      print(authException.toString());
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

    _smsCodeSent(String verificationId, List<int> code) {
      setState(() {
        vcDone = true;
        cooldown = true;
      });
      Navigator.pop(context);
      _smsVerificationCode = verificationId;
    }

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20.0))),
          title: new Text("Please wait",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                "Sending Verification Code to HP number...",
                style: TextStyle(fontWeight: FontWeight.w300),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(child: Image.asset("assets/images/loading.gif")),
              )
            ],
          ),
        );
      },
    );

    //Conduct Verification Code Sending
    await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: cc + hpController.text,
        timeout: Duration(seconds: 30),
        verificationCompleted: (authCredential) =>
            _verificationComplete(authCredential),
        verificationFailed: (authException) =>
            _verificationFailed(authException),
        codeSent: (verificationId, [code]) =>
            _smsCodeSent(verificationId, [code]),
        codeAutoRetrievalTimeout: (verificationId, [code]) =>
            _smsCodeSent(verificationId, [code]));
  }

  @override
  void dispose() {
    if(this.mounted){
      if(_timer!=null){
        _timer.cancel();
      }
    }
    super.dispose();
  }

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
      child: Padding(
        padding: const EdgeInsets.only(top: 30.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: Center(child: Text("Login",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 28),),),
              ),
              Padding(
                padding: const EdgeInsets.only(top:20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * 0.15,
                      child: CountryCodePicker(
                        onChanged: (countryCode) {
                          cc = countryCode.toString();
                        },
                        initialSelection: "+60",
                        showFlag: false,
                        showFlagDialog: true,
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      child: Column(
                        children: <Widget>[
                          TextFormField(
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(vcNode),
                            controller: hpController,
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w300),
                            obscureText: false,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                                icon: Icon(
                                  Icons.phone_android,
                                  color: Theme.of(context).primaryColor,
                                ),
                                contentPadding:
                                EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                                labelText: "Phone No. ",
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                    borderRadius: BorderRadius.circular(32.0))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * 0.2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: RaisedButton(
                          onPressed: !cooldown
                              ? () async {
                            if (hpController.text.toString().length < 1) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20.0))),
                                    title: new Text(
                                      "Verification Code Not Sent",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    content: new Text(
                                      "Please fill in a valid Phone Number!",
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
                            } else {
                              //Start timer
                              setState(() {
                                cooldown = true;
                              });
                              //Send Verification Code Function
                              _sendPhoneVeri();
                              int _start = 30;
                              const oneSec = const Duration(seconds: 1);
                              _timer = new Timer.periodic(
                                oneSec,
                                    (Timer timer) => setState(
                                      () {
                                    if (_start < 1) {
                                      cooldown = false;
                                      timer.cancel();
                                    } else {
                                      _start = _start - 1;
                                      numTimer = _start;
                                    }
                                  },
                                ),
                              );
                            }
                          }
                              : null,
                          color: Theme.of(context).primaryColor,
                          child: cooldown
                              ? FittedBox(
                            child: Text(
                              "Resend(" + numTimer.toString() + ")",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                              : FittedBox(
                            child: Text(
                              "Send Code",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: TextFormField(
                        textInputAction: TextInputAction.done,
                        focusNode: vcNode,
                        controller: vcController,
                        style: TextStyle(
                            color:Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w300),
                        obscureText: true,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                            contentPadding:
                            EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                            labelText: "Verification Code",
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor),
                                borderRadius: BorderRadius.circular(32.0))),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: ButtonTheme(
                    minWidth: MediaQuery.of(context).size.width * 0.98,
                    child: RaisedButton.icon(
                      icon: Icon(
                        Icons.phone_android,
                        color: Colors.white,
                      ),
                      onPressed: vcDone
                          ? () async {
                        if (hpController.text.length < 1 ||
                            vcController.text.length < 1) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(20.0))),
                                title: new Text(
                                  "Login Failed!",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                content: new Text(
                                  "Please make sure every field is filled!",
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
                        } else {
                          AuthCredential _credential =
                          await PhoneAuthProvider.getCredential(
                              verificationId: _smsVerificationCode,
                              smsCode: vcController.text.toString());
                          _firebaseAuth
                              .signInWithCredential(_credential)
                              .catchError((onError) {
                            if (onError != null) {
                              print(_smsVerificationCode);
                              print("Wrong code!" + onError.toString());
                              Scaffold.of(context).showSnackBar(SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text("Wrong code entered!",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w300)),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          });
                        }
                      }
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(18.0),
                      ),
                      label: Text(
                        'VERIFY',
                        style: TextStyle(color: Colors.white),
                      ),
                      color: Color.fromRGBO(1, 208, 249, 1.0),
                    )),
              ),
              Padding(
                padding: const EdgeInsets.only(
                    top: 0, left: 0, right: 0, bottom: 15.0),
                child: ButtonTheme(
                  minWidth: MediaQuery.of(context).size.width * 0.98,
                  child: RaisedButton.icon(
                    icon: Icon(Icons.cancel,color: Colors.white,),
                    shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(18.0),
                        side: BorderSide(color: Colors.redAccent)),
                    color: Colors.redAccent,
                    label: Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}