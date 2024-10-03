import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:employee/main.dart'; 
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; // For date formatting

class EmployeeDashboard extends StatefulWidget {
  @override
  _EmployeeDashboardState createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  final User? user = FirebaseAuth.instance.currentUser;
  late String userEmail;
  late String managerEmail;
  Map<String, dynamic>? officeLocation;
  double proximity = 0.0; // in meters

  bool _isInOffice = false;
  String _statusMessage = 'Checking location...';
  double _distanceFromOffice = 0.0;
  Duration _timeInOffice = Duration(seconds: 0);
  Timer? _timer;
  Location _location = Location();

  @override
  void initState() {
    super.initState();
    userEmail = user?.email?.toLowerCase() ?? '';
    _fetchManagerDetails();
  }

  Future<void> _fetchManagerDetails() async {
    try {
      // Get employee details
      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(userEmail)
          .get();

      if (employeeDoc.exists) {
        managerEmail = employeeDoc['managerEmail'];
        // Get manager details
        DocumentSnapshot managerDoc = await FirebaseFirestore.instance
            .collection('managers')
            .doc(managerEmail)
            .get();

        if (managerDoc.exists) {
          officeLocation = managerDoc['officeLocation'];
          proximity = (managerDoc['proximity'] as num).toDouble();
          _startLocationTracking();
        } else {
          // Manager document does not exist
          setState(() {
            _statusMessage = 'Manager details not found.';
          });
        }
      } else {
        // Employee document does not exist
        setState(() {
          _statusMessage = 'Employee details not found.';
        });
      }
    } catch (e) {
      print('Error fetching manager details: $e');
      setState(() {
        _statusMessage = 'Error fetching details.';
      });
    }
  }

  Future<void> _startLocationTracking() async {
    // Request permissions
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    // Check if service is enabled
    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        setState(() {
          _statusMessage = 'Location services are disabled.';
        });
        return;
      }
    }

    // Check for permissions
    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        setState(() {
          _statusMessage = 'Location permissions are denied.';
        });
        return;
      }
    }

    // Start listening to location changes
    _location.onLocationChanged.listen((LocationData currentLocation) {
      _handleLocationUpdate(currentLocation);
    });
  }

  void _handleLocationUpdate(LocationData currentLocation) async {
    if (officeLocation == null) return;

    double distance = Geolocator.distanceBetween(
      currentLocation.latitude!,
      currentLocation.longitude!,
      officeLocation!['latitude'],
      officeLocation!['longitude'],
    );

    setState(() {
      _distanceFromOffice = distance;
    });

    if (distance <= proximity) {
      // Employee is in the office
      if (!_isInOffice) {
        // Just entered the office zone
        setState(() {
          _isInOffice = true;
          _statusMessage = 'You are in the office.';
        });
        _startTimer();
        _updateAttendanceStatus(true);
      }
    } else {
      // Employee is outside the office
      if (_isInOffice) {
        // Just left the office zone
        setState(() {
          _isInOffice = false;
          _statusMessage = 'You are outside the office.';
        });
        _stopTimer();
        _updateAttendanceStatus(false);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _timeInOffice = _timeInOffice + Duration(seconds: 1);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  Future<void> _updateAttendanceStatus(bool isInOffice) async {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String documentId = '$userEmail\_$date';

    DocumentReference attendanceDoc = FirebaseFirestore.instance
        .collection('attendance')
        .doc(documentId);

    if (isInOffice) {
      // Employee just entered the office
      // Update or create attendance record
      await attendanceDoc.set({
        'employeeEmail': userEmail,
        'date': date,
        'managerEmail': managerEmail,
        'inOutTimes': FieldValue.arrayUnion([
          {'inTime': Timestamp.now(), 'outTime': null}
        ]),
        //'totalWorkDuration': 0.0,
      }, SetOptions(merge: true));
    } else {
      // Employee just left the office
      // Update the last inOutTime entry with outTime
      DocumentSnapshot docSnapshot = await attendanceDoc.get();
      if (docSnapshot.exists) {
        List<dynamic> inOutTimes = docSnapshot['inOutTimes'] ?? [];
        if (inOutTimes.isNotEmpty) {
          // Find the last entry with null outTime
          for (int i = inOutTimes.length - 1; i >= 0; i--) {
            if (inOutTimes[i]['outTime'] == null) {
              inOutTimes[i]['outTime'] = Timestamp.now();

              // Calculate duration
              Timestamp inTimestamp = inOutTimes[i]['inTime'];
              Timestamp outTimestamp = inOutTimes[i]['outTime'];
              Duration duration = outTimestamp.toDate().difference(inTimestamp.toDate());

              // Update totalWorkDuration
              double totalWorkDuration = (docSnapshot['totalWorkDuration'] as num?)?.toDouble() ?? 0.0;
              totalWorkDuration += duration.inSeconds / 3600.0; // Convert to hours

              await attendanceDoc.update({
                'inOutTimes': inOutTimes,
                'totalWorkDuration': totalWorkDuration,
              });
              break;
            }
          }
        }
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    _updateAttendanceStatus(false);
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.login,
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours.remainder(24));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    String userName = user?.displayName??"No Name";

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Welcome, $userName',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            _buildStatusCard(),
            SizedBox(height: 20),
            _buildTimerCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _isInOffice ? Colors.green : Colors.red,
      child: ListTile(
        title: Text(
          _statusMessage,
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        subtitle: !_isInOffice
            ? Text(
                'Distance from office: ${_distanceFromOffice.toStringAsFixed(2)} meters',
                style: TextStyle(color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildTimerCard() {
    return Card(
      child: ListTile(
        title: Text(
          'Time in Office',
          style: TextStyle(fontSize: 18),
        ),
        subtitle: Text(
          _formatDuration(_timeInOffice),
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}