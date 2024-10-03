import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:employee/screens/login_page.dart';
import 'package:employee/screens/employee_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(EmployeeApp());
}
class Routes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';

}
class EmployeeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: Routes.login,
      routes: {
        Routes.login: (context) => LoginPage(),
        Routes.dashboard: (context) => EmployeeDashboard(),
        // Add other routes here
      },
    );
  }
}
