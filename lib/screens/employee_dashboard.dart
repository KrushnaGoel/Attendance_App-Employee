import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:employee/main.dart'; 
class EmployeeDashboard extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    //String userEmail = user?.email ?? 'No Email';
    String userName = user?.displayName??'No Name';

    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Text('Welcome, $userName'),
      ),
    );
  }
}
