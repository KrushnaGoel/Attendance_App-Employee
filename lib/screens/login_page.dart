import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:employee/main.dart'; // Import the routes

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isSigningIn = false;
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await FirebaseAuth.instance.signOut();
      await googleSignIn.signOut();
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _isSigningIn = false;
        });
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google user credential
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Check if the user is an employee
      String userEmail = userCredential.user!.email!.toLowerCase();
      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(userEmail)
          .get();

      if (employeeDoc.exists) {
        // User is an employee, navigate to the dashboard
        Navigator.pushReplacementNamed(context, Routes.dashboard);
      } else {
        // User is not an employee, sign out and show error
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access denied. You are not registered as an employee.')),
        );
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during sign-in. Please try again.')),
      );
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  void _onSignInButtonPressed() {
    _signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Login'),
      ),
      body: Center(
        child: _isSigningIn
            ? CircularProgressIndicator()
            : ElevatedButton.icon(
                //icon: Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: _onSignInButtonPressed,
              ),
      ),
    );
  }
}
