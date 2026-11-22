
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

const Color _navy = Color(0xFF17243A);
const Color _blue = Color(0xFF3867D6);
const Color _green = Color(0xFF16865B);
const Color _red = Color(0xFFD94C4C);
const Color _muted = Color(0xFF8290A5);
const Color _border = Color(0xFFE8EDF4);

class ShepherdManagementScreen extends StatefulWidget {
  final ApiService apiService;

  const ShepherdManagementScreen({
    super.key,
    required this.apiService,
  });

  @override
  State<ShepherdManagementScreen> createState() =>
      _ShepherdManagementScreenState();
}

class _ShepherdManagementScreenState
    extends State<ShepherdManagementScreen> {
  List<dynamic> shepherds = [];

  bool loading = true;
  bool refreshing = false;
  bool creatingInvitation = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadShepherds();
  }

  Future<void> loadShepherds() async {
    if (refreshing) return;

    refreshing = true;

    if (mounted) {
      setState(() {
        loading = shepherds.isEmpty;
        error = null;
      });
    }

    try {
      final data = await widget.apiService.get(
        '/api/auth/shepherds/',
      );

      if (!mounted) return;

      if (data is List) {
        setState(() {
          shepherds = data;
          loading = false;
        });
      } else {
        throw Exception('Unexpected server response.');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    } finally {
      refreshing = false;
    }
  }

  Future<void> createInvitation() async {
    final usernameController = TextEditingController();

    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? validationError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add a shepherd'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create an invitation for a new shepherd. '
                      'They will choose their own password when '
                      'activating their account.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'USERNAME',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usernameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. shepherd02',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: validationError,
                      ),
                      onSubmitted: (_) {
                        final value =
                            usernameController.text.trim();

                        if (value.isEmpty) {
                          setDialogState(() {
                            validationError =
                                'Please enter a username.';
                          });
                        } else {
                          Navigator.pop(dialogContext, value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final value =
                        usernameController.text.trim();

                    if (value.isEmpty) {
                      setDialogState(() {
                        validationError =
                            'Please enter a username.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, value);
                  },
                  icon: const Icon(Icons.send, size: 17),
                  label: const Text('Create invitation'),
                ),
              ],
            );
          },
        );
      },
    );

    usernameController.dispose();

    if (username == null || !mounted) return;

    setState(() {
      creatingInvitation = true;
    });

    try {
      final response = await widget.apiService.post(
        '/api/auth/invitations/create/',
        {'username': username},
      );

      if (!mounted) return;

      if (response is! Map ||
          response['token'] == null) {
        throw Exception(
          'The server returned an invalid invitation response.',
        );
      }

      setState(() {
        creatingInvitation = false;
      });

      await showInvitationResult(
        username: response['username']?.toString() ?? username,
        token: response['token'].toString(),
        expiresAt: response['expires_at']?.toString(),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        creatingInvitation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create invitation: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: _red,
        ),
      );
    }
  }

  Future<void> showInvitationResult({
    required String username,
    required String token,
    String? expiresAt,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: _green,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Invitation created'),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'An invitation for "$username" has been created.',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'INVITATION TOKEN',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Center(
                    child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                        ),
                    child: Column(
                        children: [
                            QrImageView(
                            data: token,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                    const SizedBox(height: 10),
                    const Text(
                    'Scan to receive invitation token',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                    ),
                    ),
                ],
            ),
        ),
    ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: token),
                    );

                    if (!mounted || !dialogContext.mounted) return;

                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                        content: Text('Invitation token copied.'),
                        ),
                    );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy invitation token'),
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Expires: ${formatDate(expiresAt)}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Share this token securely with the shepherd. '
                  'They will need it to activate their account. '
                  'The invitation expires after 24 hours.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> revokeShepherd(
    Map<String, dynamic> shepherd,
  ) async {
    final username =
        shepherd['username']?.toString() ?? 'this shepherd';
    final id = shepherd['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke shepherd access?'),
        content: Text(
          'Are you sure you want to disable $username? '
          'This account will no longer be able to log in. '
          'Its existing records will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke access'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.apiService.post(
        '/api/auth/shepherds/$id/revoke/',
        {},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access revoked for $username.')),
      );

      await loadShepherds();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not revoke access: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return 'Never';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Unknown';

    return '${date.toLocal()}'.substring(0, 16);
  }

  Widget buildStatus(bool active) {
    final color = active ? _green : _red;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'ACTIVE' : 'DISABLED',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildLocation(dynamic location) {
    if (location == null) {
      return const Text(
        'No GPS position recorded',
        style: TextStyle(color: _muted, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lat: ${location['lat']}',
          style: const TextStyle(
            color: _navy,
            fontSize: 11,
          ),
        ),
        Text(
          'Lon: ${location['lon']}',
          style: const TextStyle(
            color: _navy,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Last update: ${formatDate(location['recorded_at'])}',
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget buildShepherdCard(
    Map<String, dynamic> shepherd,
  ) {
    final active = shepherd['is_active'] == true;
    final location = shepherd['last_location'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shepherd['username']?.toString() ?? 'Unknown',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              buildStatus(active),
            ],
          ),
          const Divider(height: 28),
          const Text(
            'ACCOUNT INFORMATION',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Account created: ${formatDate(shepherd['created_at'])}',
            style: const TextStyle(
              color: _navy,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'LATEST GPS POSITION',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          buildLocation(location),
          if (active) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => revokeShepherd(shepherd),
                icon: const Icon(Icons.block, color: _red),
                label: const Text(
                  'Revoke access',
                  style: TextStyle(color: _red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = shepherds.where(
      (s) => s['is_active'] == true,
    ).length;

    return RefreshIndicator(
      onRefresh: loadShepherds,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shepherd Management',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Manage your farm team and monitor their GPS positions.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: refreshing ? null : loadShepherds,
                      icon: const Icon(
                        Icons.refresh,
                        color: _navy,
                      ),
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: creatingInvitation
                          ? null
                          : createInvitation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      icon: creatingInvitation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: const Text('Add Shepherd'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!loading && error == null)
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          'TOTAL SHEPHERDS',
                          '${shepherds.length}',
                          Icons.people_outline,
                          _blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          'ACTIVE ACCOUNTS',
                          '$activeCount',
                          Icons.verified_user_outlined,
                          _green,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (error != null)
                  _message(
                    Icons.cloud_off_outlined,
                    'Unable to load shepherds',
                    error!,
                    () => loadShepherds(),
                  )
                else if (shepherds.isEmpty)
                  _message(
                    Icons.people_outline,
                    'No shepherds yet',
                    'Create an invitation using the Add Shepherd button.',
                    () => loadShepherds(),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth >= 850 ? 2 : 1;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 290,
                        ),
                        itemCount: shepherds.length,
                        itemBuilder: (context, index) {
                          return buildShepherdCard(
                            Map<String, dynamic>.from(
                              shepherds[index],
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: _navy,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String message,
    VoidCallback onRetry,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: _muted, size: 35),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
