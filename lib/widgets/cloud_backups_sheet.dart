import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';
import '../config/theme.dart';

class CloudBackupsSheet extends StatefulWidget {
  final bool isSelectionMode;
  const CloudBackupsSheet({super.key, this.isSelectionMode = false});

  @override
  State<CloudBackupsSheet> createState() => _CloudBackupsSheetState();
}

class _CloudBackupsSheetState extends State<CloudBackupsSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _backups = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final backups = await BackupService.instance.getCloudBackups();
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF475569);
    final cardColor = isDark ? const Color(0xFF151D30) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cloud Backups',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Restore database backups from the cloud. This will overwrite all current device data.',
            style: GoogleFonts.plusJakartaSans(
              color: subTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadBackups,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_backups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'No cloud backups found.',
                      style: GoogleFonts.plusJakartaSans(color: subTextColor),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _backups.length,
                itemBuilder: (context, index) {
                  final backup = _backups[index];
                  final date = backup['created'] as DateTime;
                  final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(date);
                  final sizeStr = BackupService.instance.formatSize(backup['size'] as int);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_download, color: AppTheme.primaryBlue),
                      ),
                      title: Text(
                        dateStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Size: $sizeStr',
                            style: GoogleFonts.plusJakartaSans(
                              color: subTextColor,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Includes: Inventory, Sales, Expenses, Settings',
                            style: GoogleFonts.plusJakartaSans(
                              color: subTextColor.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () async {
                          if (widget.isSelectionMode) {
                            Navigator.pop(context, backup);
                          } else {
                            Navigator.pop(context); // Close bottom sheet
                            await BackupService.instance.restoreCloudBackup(context, backup['ref']);
                          }
                        },
                        child: Text(
                          widget.isSelectionMode ? 'Select' : 'Restore',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
