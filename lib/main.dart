import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pawsearch/home.dart';
import 'package:provider/provider.dart';
import 'package:pawsearch/firebase/auth.dart';
import 'package:pawsearch/wrapper.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: "PawSearch",
    home: PawSearchApp(),
    theme: ThemeData(
      primaryColor: Colors.blueGrey[900],
      fontFamily: 'Baloo2',
    ),
  ));
}

class PawSearchApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamProvider<FirebaseUser>.value(
        value: FireAuth().user,
        child: Wrapper()
    );
  }
}


