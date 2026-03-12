import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/storage/token_storage.dart';
import 'package:lms/features/attendance/view_attendance/presentation/screens/selfie_preview_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/dashboard/data/models/attendance_day_data.dart';

class AttendanceDayDetailBottomSheet extends StatefulWidget {
  final DateTime date;
  final AttendanceDayData? data;

  const AttendanceDayDetailBottomSheet({
    super.key,
    required this.date,
    required this.data,
  });

  @override
  State<AttendanceDayDetailBottomSheet> createState() =>
      _AttendanceDayDetailBottomSheetState();

  ////////////////////////////////////////////////////////////
  // SHOW METHOD
  ////////////////////////////////////////////////////////////

  static void show(
    BuildContext context, {
    required DateTime date,
    required AttendanceDayData? data,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AttendanceDayDetailBottomSheet(date: date, data: data),
    );
  }
}

class _AttendanceDayDetailBottomSheetState
    extends State<AttendanceDayDetailBottomSheet> {
  int currentPage = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController(viewportFraction: 0.95);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  ////////////////////////////////////////////////////////////
  // STATUS COLOR
  ////////////////////////////////////////////////////////////

  Color _statusColor(String? status, ColorScheme scheme) {
    switch (status) {
      case "On-Time":
        return Colors.green;

      case "Late":
        return Colors.orange;

      case "Absent":
        return scheme.error;

      case "Holiday":
        return Colors.blue;

      case "On-Leave":
        return Colors.purple;

      default:
        return scheme.outline;
    }
  }

  ////////////////////////////////////////////////////////////
  // TIME FORMAT
  ////////////////////////////////////////////////////////////

  String _formatTime(DateTime? dt) {
    if (dt == null) return "--";
    return DateFormat('hh:mm a').format(dt);
  }

  ////////////////////////////////////////////////////////////
  // MAIN UI
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final formattedDate = DateFormat('EEEE, dd MMM yyyy').format(widget.date);

    final status = widget.data?.status ?? "No Data";

    final hours = widget.data?.totalHours ?? 0;

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //////////////////////////////////////////////////////
              // HANDLE
              //////////////////////////////////////////////////////
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              //////////////////////////////////////////////////////
              // DATE
              //////////////////////////////////////////////////////
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),

              const SizedBox(height: 16),

              //////////////////////////////////////////////////////
              // STATUS + HOURS
              //////////////////////////////////////////////////////
              Row(
                children: [
                  _statusBadge(context, status),

                  const Spacer(),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${hours.toStringAsFixed(1)} h",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),

                      Text(
                        "Working Hours",
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              //////////////////////////////////////////////////////
              // SESSIONS
              //////////////////////////////////////////////////////
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: widget.data?.sessions.length ?? 0,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final session = widget.data!.sessions[index];

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _sessionTile(context, session),
                    );
                  },
                ),
              ),

              if ((widget.data?.sessions.length ?? 0) > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.data!.sessions.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: currentPage == index ? 10 : 6,
                        height: currentPage == index ? 10 : 6,
                        decoration: BoxDecoration(
                          color: currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

              if (widget.data?.sessions.isEmpty ?? true)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "No attendance sessions",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  // STATUS BADGE
  ////////////////////////////////////////////////////////////

  Widget _statusBadge(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;

    final color = _statusColor(status, scheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  // SESSION TILE
  ////////////////////////////////////////////////////////////

  Widget _sessionTile(BuildContext context, AttendanceSessionData session) {
    final scheme = Theme.of(context).colorScheme;

    final hasSelfie =
        session.checkInSelfie != null || session.checkOutSelfie != null;

    final hasLocation = session.lat != null && session.lng != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Session ${currentPage + 1} of ${widget.data?.sessions.length ?? 0}",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 6),
          //////////////////////////////////////////////////////
          // TIME ROW
          //////////////////////////////////////////////////////
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: scheme.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                "${_formatTime(session.checkIn)}  →  ${_formatTime(session.checkOut)}",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            "${session.hours.toStringAsFixed(1)} hours",
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),

          //////////////////////////////////////////////////////
          // SELFIES
          //////////////////////////////////////////////////////
          if (hasSelfie)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  if (session.checkInSelfie != null)
                    _selfiePreview(context, "Check-In", session.checkInSelfie!),

                  if (session.checkInSelfie != null &&
                      session.checkOutSelfie != null)
                    const SizedBox(width: 12),

                  if (session.checkOutSelfie != null)
                    _selfiePreview(
                      context,
                      "Check-Out",
                      session.checkOutSelfie!,
                    ),
                ],
              ),
            ),

          //////////////////////////////////////////////////////
          // LOCATION MAP
          //////////////////////////////////////////////////////
          if (hasLocation)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Check-in Location",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 2),

                  //////////////////////////////////////////////////////
                  // CITY NAME
                  //////////////////////////////////////////////////////
                  FutureBuilder<String?>(
                    future: fetchCityName(session.lat!, session.lng!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          "📍 Loading location...",
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        );
                      }

                      final city = snapshot.data;

                      if (city == null) return const SizedBox();

                      return Text(
                        "📍 $city",
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 6),

                  //////////////////////////////////////////////////////
                  // MAP PREVIEW
                  //////////////////////////////////////////////////////
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(
                        "https://www.google.com/maps/search/?api=1&query=${session.lat},${session.lng}",
                      );

                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          //////////////////////////////////////////////////////
                          // MAP
                          //////////////////////////////////////////////////////
                          SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(
                                  session.lat!,
                                  session.lng!,
                                ),
                                initialZoom: 13,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                  userAgentPackageName: "com.your.app",
                                ),

                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(session.lat!, session.lng!),
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                        size: 34,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          //////////////////////////////////////////////////////
                          // PIN ICON
                          //////////////////////////////////////////////////////
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),

                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Colors.black.withOpacity(.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          //////////////////////////////////////////////////////
                          // TAP LABEL
                          //////////////////////////////////////////////////////
                          Positioned(
                            bottom: 6,
                            left: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.45),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Tap to open map",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> fetchCityName(double lat, double lng) async {
    try {
      final dio = Dio();

      final res = await dio.get(
        "https://nominatim.openstreetmap.org/reverse",
        queryParameters: {"lat": lat, "lon": lng, "format": "json"},
        options: Options(headers: {"User-Agent": "lms-attendance-app"}),
      );

      final address = res.data["address"];

      return address["city"] ??
          address["town"] ??
          address["village"] ??
          address["state"];
    } catch (_) {
      return null;
    }
  }

  Widget _selfiePreview(BuildContext context, String label, String fileName) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<String?>(
      future: TokenStorage().getJwt(),
      builder: (context, snapshot) {
        final token = snapshot.data;

        if (token == null) {
          return const SizedBox();
        }

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelfiePreviewScreen(
                        imageUrl: "${ApiConstants.selfieBaseUrl}$fileName",
                        headers: {"Authorization": "Bearer $token"},
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    "${ApiConstants.selfieBaseUrl}$fileName",
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    headers: {"Authorization": "Bearer $token"},
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 20),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
