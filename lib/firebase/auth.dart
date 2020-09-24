import 'package:firebase_auth/firebase_auth.dart';
import 'package:pawsearch/firebase/database.dart';

class FireAuth{

  final FirebaseAuth _auth = FirebaseAuth.instance;

  //Auth Changes Stream
  Stream<FirebaseUser> get user{
    return _auth.onAuthStateChanged;
  }

  //Register
  Future registerEmail(String name, String email, String hp, String pw) async{
    String status = "Pending";
    try{
      AuthResult regResult = await _auth.createUserWithEmailAndPassword(email: email, password: pw);
      if(regResult.user!=null){
        FirebaseUser user = regResult.user;
        await Database(user.uid).updateUser(name, hp);

        signInEmail(email, pw);
      }
    }
    catch(e){
      print("Register failed! "+e.toString());
      status = "Register failed ! "+e.toString();
      return status;
    }
  }

  //sign in with Email & Password
  Future signInEmail(String email, String password) async{
    try{
      AuthResult authResult = await _auth.signInWithEmailAndPassword(email: email, password: password);
      FirebaseUser user = authResult.user;
      return user;
    }
    catch(e){
      print("Login failed! "+e.toString());
      return "Login failed ! "+e.toString();
    }
  }

  //Logout
  Future signOutUser() async {
    try{
      return await _auth.signOut();
    }
    catch(e){
      print("Sign out failed!"+e.toString());
      return null;
    }
  }

  //Get current user
  Future<FirebaseUser> getCurrentUser() async{
    try{
      return await _auth.currentUser();
    }
    catch(e){
      return null;
    }
  }

}