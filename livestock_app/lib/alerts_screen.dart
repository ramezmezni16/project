import 'package:flutter/material.dart';
import 'services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  final ApiService apiService;

  const AlertsScreen({
    super.key,
    required this.apiService,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> alerts = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await widget.apiService.get('/api/alerts/');

      if (result is! List) {
        throw Exception('Unexpected response from the server.');
      }

      if (!mounted) return;

      setState(() {
        alerts = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  Color severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange.shade800;
      default:
        return Colors.blue;
    }
  }

  IconData alertIcon(String type) {
    switch (type.toUpperCase()) {
      case 'ESCAPE':
        return Icons.warning_amber_rounded;
      case 'RUSH':
        return Icons.speed;
      case 'STILL':
        return Icons.pause_circle_outline;
      case 'LOW_BATTERY':
        return Icons.battery_alert;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF17243A),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Monitoring events and livestock warnings',
                      style: TextStyle(
                        color: Color(0xFF8290A5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh alerts',
                onPressed: loading ? null : loadAlerts,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 42,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              error!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: loadAlerts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : alerts.isEmpty
                      ? RefreshIndicator(
                          onRefresh: loadAlerts,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 110),
                              Icon(
                                Icons.notifications_none,
                                size: 60,
                                color: Color(0xFFB0BAC8),
                              ),
                              SizedBox(height: 16),
                              Center(
                                child: Text(
                                  'No alerts yet',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF17243A),
                                  ),
                                ),
                              ),
                              SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'New monitoring alerts will appear here.',
                                  style: TextStyle(
                                    color: Color(0xFF8290A5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: loadAlerts,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: alerts.length,
                            itemBuilder: (context, index) {
                              final alert = alerts[index];

                              if (alert is! Map) {
                                return const SizedBox.shrink();
                              }

                              final type =
                                  (alert['alert_type'] ?? 'ALERT').toString();
                              final severity =
                                  (alert['severity'] ?? 'INFO').toString();
                              final message =
                                  (alert['message'] ?? 'No details provided.')
                                      .toString();
                              final tracker =
                                  (alert['tracker_id'] ?? 'Unknown').toString();
                              final date = formatDate(
                                alert['ts'] ?? alert['created_at'],
                              );

                              final color = severityColor(severity);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFFE8EDF4),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.10),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              alertIcon(type),
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              type.replaceAll('_', ' '),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF17243A),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.10),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              severity,
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: Color(0xFF44536A),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.sensors_outlined,
                                            size: 15,
                                            color: Color(0xFF8290A5),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            tracker,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF8290A5),
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: Color(0xFF8290A5),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            date,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF8290A5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}