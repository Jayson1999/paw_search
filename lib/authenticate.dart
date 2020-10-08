import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pawsearch/register.dart';

import 'login.dart';

class Authenticate extends StatefulWidget {
  @override
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: exitDialog,
      child: Scaffold(
        body: Center(
            child: SingleChildScrollView(
                child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(50),
              child: CircleAvatar(
                minRadius: (MediaQuery.of(context).size.width / 2) - 50,
                backgroundImage: FadeInImage(
                  image: Image.asset("assets/images/startuplogo.png").image,
                  placeholder: Image.asset("assets/images/loading.gif").image,
                ).image,
                backgroundColor: Colors.white70,
              ),
            ),
            ButtonTheme(minWidth: 300, child: new LoginButton()),
            ButtonTheme(minWidth: 300, child: new RegisterButton())
          ],
        ))),
        backgroundColor: Colors.white,
      ),
    );
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
