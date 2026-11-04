import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'map_screen.dart';

void main() {
  runApp(const LivestockApp());
}

final String apiUrl =
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';

const Color navy = Color(0xFF17243A);
const Color blue = Color(0xFF3867D6);
const Color background = Color(0xFFF5F7FB);
const Color muted = Color(0xFF8290A5);
const Color border = Color(0xFFE8EDF4);
const Color green = Color(0xFF16865B);
const Color red = Color(0xFFD94C4C);

class LivestockApp extends StatelessWidget {
  const LivestockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Livestock Monitor',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> trackers = [];
  List<dynamic> zones = [];
  bool zonesRefreshing = false;

  bool loading = true;
  bool refreshing = false;
  bool connected = false;

  int page = 0; // 0 = overview, 1 = map

  String? error;
  DateTime? lastUpdated;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();

    fetchTrackers(showLoading: true);
    fetchZones();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        fetchTrackers();
        fetchZones();
          },
    );
  }
  

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchTrackers({bool showLoading = false}) async {
    if (refreshing) return;

    refreshing = true;

    if (showLoading && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/analytics/anomalies/'),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        trackers = data['results'] ?? [];
        connected = true;
        loading = false;
        error = null;
        lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        connected = false;
        loading = false;
        error = e.toString();
      });
    } finally {
      refreshing = false;
    }
  }
  Future<void> fetchZones() async {
  if (zonesRefreshing) return;

  zonesRefreshing = true;

  try {
    final response = await http.get(
      Uri.parse('$apiUrl/api/analytics/clusters/'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Zones API returned ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (!mounted) return;

    setState(() {
      zones = data['habitual_zones'] ?? [];
    });
  } catch (e) {
    debugPrint('Could not load grazing zones: $e');
  } finally {
    zonesRefreshing = false;
  }
}

  @override
  Widget build(BuildContext context) {
    final anomalies = trackers.where(
      (t) => t['is_anomaly'] == true,
    ).length;

    final normal = trackers.length - anomalies;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Scaffold(
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: (i) => setState(() => page = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      label: 'Map',
                    ),
                  ],
                ),
          body: Row(
            children: [
              if (wide)
                Sidebar(
                  selected: page,
                  onSelect: (i) => setState(() => page = i),
                ),

              Expanded(
                child: Column(
                  children: [
                    buildTopBar(),

                    Expanded(
                      child: loading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : page == 1
                              ? MapScreen(
                                  trackers: trackers,
                                  zones: zones,
                                )
                              : buildOverview(wide, anomalies, normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildOverview(bool wide, int anomalies, int normal) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        wide ? 32 : 18,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1400,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeading(),

              const SizedBox(height: 28),

              buildMetrics(
                anomalies,
                normal,
              ),

              const SizedBox(height: 30),

              buildSectionHeader(),

              const SizedBox(height: 14),

              if (error != null && trackers.isEmpty)
                buildError()
              else
                buildTrackerSection(wide),

              const SizedBox(height: 24),

              buildModelInfo(),

              const SizedBox(height: 24),

              buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          Text(
            page == 0 ? 'LIVESTOCK / OVERVIEW' : 'LIVESTOCK / MAP',
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFFEAF7F0)
                  : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: connected ? green : red,
                ),
                const SizedBox(width: 8),
                Text(
                  connected ? 'API CONNECTED' : 'API DISCONNECTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: connected ? green : red,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          IconButton(
            onPressed: () {
              fetchTrackers(showLoading: true);
              fetchZones();
            },
            tooltip: 'Refresh data',
            icon: const Icon(
              Icons.refresh_rounded,
              color: navy,
           ),
),
        ],
      ),
    );
  }

  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Farm Overview',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: navy,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Monitor your livestock, telemetry and AI-detected anomalies.',
          style: TextStyle(
            fontSize: 13,
            color: muted,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            const Icon(
              Icons.sync,
              size: 14,
              color: blue,
            ),
            const SizedBox(width: 6),
            Text(
              lastUpdated == null
                  ? 'Waiting for data'
                  : 'Last updated: ${lastUpdated!.toLocal().toString().substring(11, 19)}',
              style: const TextStyle(
                color: muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '•',
              style: TextStyle(color: muted),
            ),
            const SizedBox(width: 8),
            const Text(
              '5-second refresh interval',
              style: TextStyle(
                color: muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildMetrics(int anomalies, int normal) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width > 900 ? 4 : width > 550 ? 2 : 1;
        final spacing = 14.0;
        final cardWidth =
            (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: 'TOTAL TRACKERS',
                value: '${trackers.length}',
                icon: Icons.pets_outlined,
                color: blue,
                description: 'Registered devices',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: 'NORMAL',
                value: '$normal',
                icon: Icons.check_circle_outline,
                color: green,
                description: 'Normal predictions',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: 'ANOMALIES',
                value: '$anomalies',
                icon: Icons.warning_amber_rounded,
                color: red,
                description: 'Unusual readings',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: 'AI ENGINE',
                value: 'ACTIVE',
                icon: Icons.memory_outlined,
                color: const Color(0xFF8058C7),
                description: 'Isolation Forest',
                isText: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tracker Monitoring',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Latest telemetry and anomaly predictions',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        if (connected)
          const StatusPill(
            label: 'MONITORING',
            color: green,
          ),
      ],
    );
  }

  Widget buildTrackerSection(bool wide) {
    if (trackers.isEmpty) {
      return const EmptyState();
    }

    if (wide) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 16,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: border),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: TableLabel('TRACKER')),
                  Expanded(child: TableLabel('SPEED')),
                  Expanded(child: TableLabel('ACTIVITY')),
                  Expanded(child: TableLabel('AI STATUS')),
                  Expanded(child: TableLabel('DECISION SCORE')),
                ],
              ),
            ),

            ...trackers.map(
              (tracker) => TrackerTableRow(
                tracker: tracker,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: trackers.map((tracker) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TrackerMobileCard(tracker: tracker),
        );
      }).toList(),
    );
  }

  Widget buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 35,
            color: red,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load tracker data',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error ?? 'Unknown error',
            style: const TextStyle(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => fetchTrackers(showLoading: true),
            child: const Text('Retry connection'),
          ),
        ],
      ),
    );
  }

  Widget buildModelInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDCE6FA),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.psychology_outlined,
            color: blue,
            size: 28,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Anomaly Detection',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: navy,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Tracker readings are analyzed using the Isolation Forest model. '
                  'An anomaly indicates unusual data, not necessarily an emergency.',
                  style: TextStyle(
                    color: Color(0xFF62738F),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFooter() {
    return Row(
      children: [
        const Text(
          'LIVESTOCK MONITOR',
          style: TextStyle(
            color: muted,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        const Text(
          'IoT Monitoring Platform',
          style: TextStyle(
            color: muted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const Sidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 245,
      color: navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 27, 20, 35),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pets,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVESTOCK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'MONITORING SYSTEM',
                      style: TextStyle(
                        color: Color(0xFF9DAEC7),
                        fontSize: 8,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(left: 24, bottom: 12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: Color(0xFF8295B1),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),

          SidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Overview',
            active: selected == 0,
            onTap: () => onSelect(0),
          ),
          SidebarItem(
            icon: Icons.map_outlined,
            label: 'Map',
            active: selected == 1,
            onTap: () => onSelect(1),
          ),

          const Spacer(),

          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF22334E),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM',
                  style: TextStyle(
                    color: Color(0xFF9DAEC7),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: Color(0xFF46C78A),
                      size: 8,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Monitoring service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 22),
            child: Text(
              'PROJECT VERSION 1.0',
              style: TextStyle(
                color: Color(0xFF8295B1),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? const Color(0xFF293D5D) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: active ? Colors.white : const Color(0xFF9DAEC7),
                  size: 19,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF9DAEC7),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;
  final bool isText;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.7,
                ),
              ),
              Icon(
                icon,
                color: color,
                size: 21,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            value,
            style: TextStyle(
              color: navy,
              fontSize: isText ? 23 : 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class TableLabel extends StatelessWidget {
  final String text;

  const TableLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: muted,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
      ),
    );
  }
}

class TrackerTableRow extends StatelessWidget {
  final Map<String, dynamic> tracker;

  const TrackerTableRow({
    super.key,
    required this.tracker,
  });

  @override
  Widget build(BuildContext context) {
    final anomaly = tracker['is_anomaly'] == true;
    final color = anomaly ? red : green;

    final score = tracker['decision_score'];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 20,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 17,
                    color: blue,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${tracker['tracker_id']}',
                  style: const TextStyle(
                    color: navy,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: DataValue(
              '${tracker['speed']} km/h',
            ),
          ),

          Expanded(
            child: DataValue(
              '${tracker['activity']}',
            ),
          ),

          Expanded(
            child: StatusPill(
              label: anomaly ? 'ANOMALY' : 'NORMAL',
              color: color,
            ),
          ),

          Expanded(
            child: DataValue(
              score is num ? score.toStringAsFixed(4) : 'N/A',
            ),
          ),
        ],
      ),
    );
  }
}

class TrackerMobileCard extends StatelessWidget {
  final Map<String, dynamic> tracker;

  const TrackerMobileCard({
    super.key,
    required this.tracker,
  });

  @override
  Widget build(BuildContext context) {
    final anomaly = tracker['is_anomaly'] == true;
    final color = anomaly ? red : green;
    final score = tracker['decision_score'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${tracker['tracker_id']}',
                style: const TextStyle(
                  color: navy,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: anomaly ? 'ANOMALY' : 'NORMAL',
                color: color,
              ),
            ],
          ),
          const Divider(height: 25),
          InfoLine('Speed', '${tracker['speed']} km/h'),
          InfoLine('Activity', '${tracker['activity']}'),
          InfoLine('Latitude', '${tracker['lat']}'),
          InfoLine('Longitude', '${tracker['lon']}'),
          InfoLine(
            'Decision score',
            score is num ? score.toStringAsFixed(4) : 'N/A',
          ),
        ],
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const InfoLine(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DataValue extends StatelessWidget {
  final String value;

  const DataValue(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: navy,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.sensors_off_outlined,
            size: 35,
            color: muted,
          ),
          SizedBox(height: 12),
          Text(
            'No tracker data available',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}