import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pawsearch/firebase/auth.dart';
import 'package:pawsearch/loading.dart';

class Authenticate extends StatefulWidget {
  @override
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: CircleAvatar(
            backgroundImage: AssetImage("assets/images/pawslogo.png"),
          ),
        ),
        title: Text(
          'Welcome to PawSearch ! ',
        ),
        backgroundColor: Colors.blueGrey[900],
        centerTitle: true,
      ),
      body: Center(
        child:SingleChildScrollView(
            child:Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(50),
                  child: CircleAvatar(
                    minRadius: (MediaQuery. of(context).size.width/2)-50,
                    backgroundImage: AssetImage("assets/images/startuplogo.png"),
                    backgroundColor: Colors.white70,
                  ),
                ),
                ButtonTheme(minWidth: 300, child: new LoginButton()),
                ButtonTheme(
                  minWidth: 300,
                  child: new RegisterButton(),
                )
              ],
            ))
      ),
      backgroundColor: Colors.white,
    );
  }
}

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
        'LOGIN',
        style: TextStyle(
          color: Colors.white
        ),
      ),
      color: Colors.blueGrey[900],
    );
  }
}

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
          'REGISTER',
          style: TextStyle(color: Colors.blueGrey[900],),
        ),
        color: Colors.blueGrey[900]);
  }
}

//LOGIN SHEET
class LoginSheet extends StatelessWidget {
  LoginSheet({
    Key key,
  }) : super(key: key);

  final FireAuth _auth = FireAuth();
  TextEditingController emailController = new TextEditingController();
  TextEditingController pwController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Form(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Center(
                child: Text(
                  "Login",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: TextField(
                controller: emailController,
                style: TextStyle(color: Colors.white),
                obscureText: false,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.alternate_email,
                      color: Colors.white,
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    hintText: "Email",
                    hintStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(32.0))),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 30.0),
              child: TextField(
                controller: pwController,
                style: TextStyle(color: Colors.white),
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.lock,
                      color: Colors.white,
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    hintText: "Password",
                    hintStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(32.0))),
              ),
            ),
            ButtonTheme(
                minWidth: MediaQuery.of(context).size.width * 0.98,
                child: RaisedButton.icon(
                  icon: Icon(Icons.mail),
                  onPressed: () async {
                    if (emailController.text.length < 1 ||
                        pwController.text.length < 1) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20.0))),
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
                      Future loginProcess() async{
                        dynamic result = await _auth.signInEmail(
                            emailController.text, pwController.text).then((value) {
                          //If login failed
                          if (value.toString().contains("failed") || value == null) {
                            print("Login Failed! Exceptions");
                            String errorMsg = "";
                            if(value.toString().contains("password")){
                              errorMsg = "Invalid Password! \n Please Try Again";
                            }
                            else if(value.toString().contains("connection")){
                              errorMsg = "No Network Connection! \n Please check your Network Connection and Try Again";
                            }
                            else if(value.toString().contains("user")){
                              errorMsg = "Invalid User! \n Please check your Email Address and Try Again";
                            }
                            else if(value.toString().contains("email")){
                              errorMsg = "Invalid Email! \n Please type in a valid Email Address!";
                            }
                            else{
                              errorMsg = value.toString();
                            }
                            //Dismiss keyboard
                            FocusScope.of(context).unfocus();
                            //DISPLAY ERROR MESSAGE IN SnackBar
                            Scaffold.of(context).showSnackBar(SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                errorMsg,
                              ),
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        });
                        return result;
                      }
                        FutureBuilder(
                          future: loginProcess(),
                          builder: (BuildContext context, AsyncSnapshot snapshot){
                            if(snapshot.hasData){
                              return null;
                            }
                            else{
                              return Loading();
                            }
                          },
                        );
                    }
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: new BorderRadius.circular(18.0),
                      side: BorderSide(color: Colors.white)),
                  label: Text(
                    'LOGIN',
                    style: TextStyle(
                        color: Colors.blueGrey[900],),
                  ),
                  color: Colors.white,
                )),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: ButtonTheme(
                  minWidth: MediaQuery.of(context).size.width * 0.98,
                  child: RaisedButton.icon(
                    icon: Icon(Icons.phone_android),
                    onPressed: () {},
                    shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(18.0),
                        side: BorderSide(color: Colors.greenAccent[700])),
                    label: Text(
                      'PHONE LOGIN',
                      style: TextStyle(
                          color: Colors.blueGrey[900],),
                    ),
                    color: Colors.greenAccent[700],
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

//REGISTER SHEET
class RegisterSheet extends StatelessWidget {
  RegisterSheet({
    Key key,
  }) : super(key: key);

  final FireAuth _auth = FireAuth();
  TextEditingController nameController = new TextEditingController();
  TextEditingController emailController = new TextEditingController();
  TextEditingController phoneController = new TextEditingController();
  TextEditingController pwController = new TextEditingController();
  TextEditingController cpwController = new TextEditingController();

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
                      fontSize: 32),
                ),
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: TextField(
                controller: nameController,
                style: TextStyle(color: Colors.blueGrey[900]),
                obscureText: false,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.account_circle,
                      color: Colors.blueGrey[900],
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    hintText: "Name",
                    hintStyle: TextStyle(color: Colors.blueGrey[900]),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueGrey[900]),
                        borderRadius: BorderRadius.circular(32.0))),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: TextField(
                controller: emailController,
                style: TextStyle(color: Colors.blueGrey[900]),
                obscureText: false,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.alternate_email,
                      color: Colors.blueGrey[900],
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    hintText: "Email",
                    hintStyle: TextStyle(color: Colors.blueGrey[900]),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueGrey[900]),
                        borderRadius: BorderRadius.circular(32.0))),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: TextField(
                controller: phoneController,
                style: TextStyle(color: Colors.blueGrey[900]),
                obscureText: false,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.phone_android,
                      color: Colors.blueGrey[900],
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    hintText: "HP No.",
                    hintStyle: TextStyle(color: Colors.blueGrey[900]),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueGrey[900]),
                        borderRadius: BorderRadius.circular(32.0))),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 30.0),
              child: TextField(
                controller: pwController,
                style: TextStyle(color: Colors.blueGrey[900]),
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.lock,
                      color: Colors.blueGrey[900],
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    hintText: "Password (At least 6 characters)",
                    hintStyle: TextStyle(color: Colors.blueGrey[900]),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueGrey[900]),
                        borderRadius: BorderRadius.circular(32.0))),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 30.0),
              child: TextField(
                controller: cpwController,
                style: TextStyle(color: Colors.blueGrey[900]),
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                    icon: Icon(
                      Icons.lock,
                      color: Colors.blueGrey[900],
                    ),
                    contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                    hintText: "Confirm Password",
                    hintStyle: TextStyle(color: Colors.blueGrey[900]),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueGrey[900]),
                        borderRadius: BorderRadius.circular(32.0))),
              ),
            ),
            ButtonTheme(
                minWidth: MediaQuery.of(context).size.width * 0.98,
                child: RaisedButton.icon(
                  icon: Icon(Icons.mail, color: Colors.white),
                  onPressed: () async {
                    if (emailController.text.length < 1 ||
                        phoneController.text.length < 1 ||
                        pwController.text.length < 1 ||
                        cpwController.text.length < 1) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20.0))),
                            title: new Text("Register Failed!",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            content: new Text(
                                "Please make sure every field is filled!",
                                style: TextStyle(
                                    color: Colors.redAccent)),
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
                    } else if (pwController.text != cpwController.text) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20.0))),
                            title: new Text("Register Failed!",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            content: new Text(
                              "Password not matched!",
                              style: TextStyle(
                                  color: Colors.redAccent),
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
//                        showDialog(
//                            barrierDismissible: false,
//                            context: context,
//                            builder: (BuildContext context) {
//                              return Loading();
//                            });
//                         //Dismiss keyboard
//                         FocusScope.of(context).unfocus();
//                        //Close dialog
//                        Navigator.of(context, rootNavigator: true).pop();
                       Future regProcess() async{
                         dynamic regResult = await _auth.registerEmail(
                             nameController.text,
                             emailController.text,
                             phoneController.text,
                             pwController.text).then((value){
                           //If Register failed
                           if (value.toString().contains("failed") || value == null) {
                             print("Registration Failed! Exceptions");
                             String errorMsg = "";
                             if(value.toString().contains("password")){
                               errorMsg = "Invalid Password! \n Please Try Again";
                             }
                             else if(value.toString().contains("connection")){
                               errorMsg = "No Network Connection! \n Please check your Network Connection and Try Again";
                             }
                             else if(value.toString().contains("user")){
                               errorMsg = "Invalid User! \n Please check your Email Address and Try Again";
                             }
                             else if(value.toString().contains("email")){
                               errorMsg = "Invalid Email! \n Please type in a valid Email Address!";
                             }
                             else{
                               errorMsg = value.toString();
                             }
                             //Dismiss keyboard
                             FocusScope.of(context).unfocus();
                             //DISPLAY ERROR MESSAGE IN SnackBar
                             Scaffold.of(context).showSnackBar(SnackBar(
                               backgroundColor: Colors.redAccent,
                               content: Text(errorMsg,),
                               behavior: SnackBarBehavior.floating,
                             ));
                           }
                         });
                         return regResult;
                       }

                        FutureBuilder(
                            future: regProcess(),
                            builder: (BuildContext context, AsyncSnapshot snapshot){
                              if(snapshot.hasData){
                                return null;
                              }
                              else{
                                return Loading();
                              }
                            },
                        );
                    }
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: new BorderRadius.circular(18.0),
                      side: BorderSide(color: Colors.blueGrey[900])),
                  label: Text(
                    'REGISTER',
                    style: TextStyle(color: Colors.white,),
                  ),
                  color: Colors.blueGrey[900],
                )),
          ],
        ),
      ),
    );
  }
}
