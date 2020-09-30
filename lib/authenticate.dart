import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pawsearch/register.dart';

import 'login.dart';

class Authenticate extends StatefulWidget {
  @override
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
