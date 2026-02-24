import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lms/core/services/location_tracking_service.dart';

class EmployeeTrackingScreen extends StatefulWidget {
  const EmployeeTrackingScreen({super.key});

  @override
  State<EmployeeTrackingScreen> createState() => _EmployeeTrackingScreenState();
}

class _EmployeeTrackingScreenState extends State<EmployeeTrackingScreen> {
  GoogleMapController? mapController;

  final LocationTrackingService trackingService = LocationTrackingService();

  List<LatLng> path = [];

  LatLng? current;
  LatLng? start;
  LatLng? end;

  double distance = 0;

  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();

    sub = trackingService.locationStream.listen((data) {
      setState(() {
        current = data.current;
        start ??= data.current;
        end = data.current;

        path = data.path;

        distance = data.totalDistance;
      });

      followCamera(data.current);
    });
  }

  void followCamera(LatLng pos) {
    mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  Set<Marker> buildMarkers() {
    final markers = <Marker>{};

    if (start != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("start"),
          position: start!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (end != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("end"),
          position: end!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (current != null) {
      markers.add(
        Marker(markerId: const MarkerId("current"), position: current!),
      );
    }

    return markers;
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Tracking")),

      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090),
              zoom: 16,
            ),

            polylines: {
              Polyline(
                polylineId: const PolylineId("path"),
                points: path,
                width: 6,
                color: Colors.blue,
              ),
            },

            markers: buildMarkers(),

            onMapCreated: (c) {
              mapController = c;
            },
          ),

          Positioned(bottom: 0, left: 0, right: 0, child: buildBottom()),
        ],
      ),
    );
  }

  Widget buildBottom() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          row("Distance", "${distance.toStringAsFixed(2)} km"),

          row("Status", "Tracking"),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: trackingService.startTracking,
            child: const Text("Start"),
          ),

          ElevatedButton(
            onPressed: trackingService.stopTracking,
            child: const Text("Stop"),
          ),
        ],
      ),
    );
  }

  Widget row(String t, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t),

        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
