import 'package:flutter/material.dart';

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
                content: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(child: Image.asset("assets/images/loading.gif")),
                )
              ),
            ],
      )),
    );
  }
}
