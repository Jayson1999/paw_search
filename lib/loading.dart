import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              AlertDialog(
                title: Text(
                  "Loading...",
                  style: TextStyle(fontFamily: "Baloo2"),
                  textAlign: TextAlign.center,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20.0))),
                backgroundColor: Colors.white,
                content: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100.0, bottom: 100.0),
                    child: SpinKitWanderingCubes(
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ),
              ),
            ],
      )),
    );
  }
}
