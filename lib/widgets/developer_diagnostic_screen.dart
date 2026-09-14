import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/startup_logger.dart';

/// Developer Diagnostic Screen displayed by `ErrorWidget.builder` whenever
/// an unhandled widget build exception occurs.
/// Displays the actual exception, stack trace, startup history, and log path.
class DeveloperDiagnosticScreen extends StatefulWidget {
  final FlutterErrorDetails details;

  const DeveloperDiagnosticScreen({super.key, required this.details});

  @override
  State<DeveloperDiagnosticScreen> createState() => _DeveloperDiagnosticScreenState();
}

class _DeveloperDiagnosticScreenState extends State<DeveloperDiagnosticScreen> {
  bool _isStackTraceExpanded = false;
  bool _copied = false;

  void _copyDetails() {
    final logPath = StartupLogger.getLogFilePath();
    final buffer = StringBuffer();
    buffer.writeln('=== QuickBill POS Diagnostic Report ===');
    buffer.writeln('Log File: $logPath');
    buffer.writeln('Exception: ${widget.details.exception}');
    buffer.writeln('\n--- Recent Startup Milestones ---');
    for (final log in StartupLogger.inMemoryLogs.take(30)) {
      buffer.writeln(log);
    }
    buffer.writeln('\n--- Stack Trace ---');
    buffer.writeln(widget.details.stack?.toString() ?? 'No stack trace available');
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logPath = StartupLogger.getLogFilePath();
    final exceptionStr = widget.details.exception.toString();
    final stackStr = widget.details.stack?.toString() ?? 'No stack trace available';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF0F172A), // Dark slate theme
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Icon and Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.terminal_rounded,
                            color: Color(0xFFEF4444),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QuickBill POS — Technical Diagnostics',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'A technical hurdle occurred during screen transition.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Primary Error Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.details.exception.runtimeType.toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFCA5A5),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Developer Mode Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade300,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            exceptionStr,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF1F5F9),
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Log path notification
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description_outlined, size: 16, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    'Log: $logPath',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stack Trace Collapsible
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isStackTraceExpanded = !_isStackTraceExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.code_rounded, size: 18, color: Color(0xFF64748B)),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Exception Stack Trace',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    _isStackTraceExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isStackTraceExpanded) ...[
                            const Divider(height: 1, color: Color(0xFF334155)),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              color: const Color(0xFF0A0F1D),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  stackStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontFamily: 'monospace',
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              RestartWidget.restartApp(context);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Restart QuickBill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981), // primaryGreen
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _copyDetails,
                          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
                          label: Text(_copied ? 'Copied!' : 'Copy Diagnostics'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            side: const BorderSide(color: Color(0xFF475569)),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
