import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pawsearch/firebase/database.dart';

class FireAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //Auth Changes Stream
  Stream<FirebaseUser> get user {
    return _auth.onAuthStateChanged;
  }

  //Logout
  Future signOutUser() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print("Sign out failed!" + e.toString());
      return null;
    }
  }

  //Get current user
  Future<FirebaseUser> getCurrentUser() async {
    try {
      return await _auth.currentUser();
    } catch (e) {
      return null;
    }
  }
}
