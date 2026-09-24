import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/csv_import_model.dart';
import '../../providers/branch_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/csv_inventory_import_service.dart';
import '../../services/sync_service.dart';

enum ImportWizardStep {
  selectFile,
  mapColumns,
  previewValidate,
  importing,
  summary,
}

class CsvImportWizardSheet extends ConsumerStatefulWidget {
  const CsvImportWizardSheet({super.key});

  /// Opens the 10x CSV Import Wizard as a responsive Dialog (on desktop)
  /// or full-height bottom sheet (on mobile).
  static Future<bool?> show(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 750;
    if (isWide) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: CsvImportWizardSheet(),
        ),
      );
    } else {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const CsvImportWizardSheet(),
      );
    }
  }

  @override
  ConsumerState<CsvImportWizardSheet> createState() => _CsvImportWizardSheetState();
}

class _CsvImportWizardSheetState extends ConsumerState<CsvImportWizardSheet> {
  ImportWizardStep _currentStep = ImportWizardStep.selectFile;

  // File state
  PlatformFile? _selectedFile;
  bool _isParsing = false;

  // CSV Data & Mapping
  CsvPreviewData? _previewData;
  Map<int, CsvColumnType> _columnMapping = {};

  // Settings
  ImportConflictStrategy _conflictStrategy = ImportConflictStrategy.updateAndAddStock;
  bool _autoGenerateBarcodes = true;

  // Preview Filter & Search
  String _previewFilter = 'all'; // 'all', 'valid', 'existing', 'errors'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Progress & Summary
  CsvImportProgress? _importProgress;
  CsvImportSummary? _importSummary;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _branchId => ref.read(branchProvider).selectedBranch?.id ?? 1;

  // ---------------------------------------------------------------------------
  // FILE SELECTION & PARSING
  // ---------------------------------------------------------------------------

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _selectedFile = result.files.single;
      _isParsing = true;
    });

    try {
      final preview = await CsvInventoryImportService.instance.parseAndValidateCsv(
        filePath: _selectedFile!.path!,
        branchId: _branchId,
      );

      setState(() {
        _previewData = preview;
        _columnMapping = Map.from(preview.columnMapping);
        _isParsing = false;

        // If both required fields (name and sellingPrice) were detected automatically,
        // we can take the user directly to Preview & Validation, with option to review mapping!
        final hasName = _columnMapping.values.contains(CsvColumnType.name);
        final hasPrice = _columnMapping.values.contains(CsvColumnType.sellingPrice);

        if (hasName && hasPrice) {
          _currentStep = ImportWizardStep.previewValidate;
        } else {
          _currentStep = ImportWizardStep.mapColumns;
        }
      });
    } catch (e) {
      setState(() => _isParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read CSV: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _downloadSampleCsv() async {
    try {
      await CsvInventoryImportService.instance.generateAndDownloadSampleCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample CSV template downloaded / shared successfully'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not download sample: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RE-PARSE WITH MANUAL COLUMN MAPPING
  // ---------------------------------------------------------------------------

  Future<void> _applyColumnMappingAndValidate() async {
    if (_selectedFile?.path == null) return;

    setState(() => _isParsing = true);

    try {
      final preview = await CsvInventoryImportService.instance.parseAndValidateCsv(
        filePath: _selectedFile!.path!,
        branchId: _branchId,
        manualColumnMapping: _columnMapping,
      );

      setState(() {
        _previewData = preview;
        _isParsing = false;
        _currentStep = ImportWizardStep.previewValidate;
      });
    } catch (e) {
      setState(() => _isParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // EXECUTE BATCH IMPORT
  // ---------------------------------------------------------------------------

  Future<void> _startImport() async {
    if (_previewData == null || _previewData!.parsedRows.isEmpty) return;

    setState(() {
      _currentStep = ImportWizardStep.importing;
      _importProgress = CsvImportProgress(
        total: _previewData!.parsedRows.length,
        processed: 0,
        currentName: 'Initializing database transaction...',
        progress: 0.0,
      );
    });

    try {
      final summary = await CsvInventoryImportService.instance.executeBatchImport(
        branchId: _branchId,
        rows: _previewData!.parsedRows,
        conflictStrategy: _conflictStrategy,
        autoGenerateBarcodes: _autoGenerateBarcodes,
        onProgress: (p) {
          if (mounted) {
            setState(() => _importProgress = p);
          }
        },
      );

      setState(() {
        _importSummary = summary;
        _currentStep = ImportWizardStep.summary;
      });

      // Invalidate inventory providers so the POS instantly has the latest stock
      ref.invalidate(productsProvider);
      ref.invalidate(lowStockProductsProvider);

      // Trigger cloud push in background
      SyncService.instance.pushLocalChanges();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        setState(() => _currentStep = ImportWizardStep.previewValidate);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD METHOD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final isWide = MediaQuery.of(context).size.width > 750;
    final maxH = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxH,
        maxWidth: isWide ? 900 : double.infinity,
      ),
      decoration: BoxDecoration(
        color: scaffoldBg,
        borderRadius: BorderRadius.circular(isWide ? 24 : 20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header & Stepper ──
          _buildHeader(isDark, textPrimary, textSecondary, border),

          // ── Content Body (Scrollable) ──
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentStepContent(
                isDark: isDark,
                cardBg: cardBg,
                border: border,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER & STEPPER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary, Color border) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advanced Inventory CSV Import',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'AI & heuristic header mapping • Conflict restock • 10x faster',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(false),
                color: textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Step indicators
          Row(
            children: [
              _buildStepIndicator(
                stepIndex: 1,
                title: 'Upload File',
                isActive: _currentStep == ImportWizardStep.selectFile,
                isCompleted: _currentStep.index > ImportWizardStep.selectFile.index,
              ),
              _buildStepDivider(_currentStep.index > ImportWizardStep.selectFile.index),
              _buildStepIndicator(
                stepIndex: 2,
                title: 'Map Columns',
                isActive: _currentStep == ImportWizardStep.mapColumns,
                isCompleted: _currentStep.index > ImportWizardStep.mapColumns.index,
              ),
              _buildStepDivider(_currentStep.index > ImportWizardStep.mapColumns.index),
              _buildStepIndicator(
                stepIndex: 3,
                title: 'Validate & Restock',
                isActive: _currentStep == ImportWizardStep.previewValidate,
                isCompleted: _currentStep.index > ImportWizardStep.previewValidate.index,
              ),
              _buildStepDivider(_currentStep.index > ImportWizardStep.previewValidate.index),
              _buildStepIndicator(
                stepIndex: 4,
                title: 'Finished',
                isActive: _currentStep == ImportWizardStep.summary,
                isCompleted: _currentStep == ImportWizardStep.summary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int stepIndex,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    final color = isCompleted
        ? AppTheme.primaryGreen
        : (isActive ? AppTheme.primaryGreen : Colors.grey.withValues(alpha: 0.5));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isCompleted ? AppTheme.primaryGreen : (isActive ? AppTheme.primaryGreen.withValues(alpha: 0.15) : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Text(
                    '$stepIndex',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppTheme.primaryGreen : Colors.grey,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppTheme.primaryGreen : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isCompleted ? AppTheme.primaryGreen : Colors.grey.withValues(alpha: 0.25),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP CONTENT ROUTER
  // ---------------------------------------------------------------------------

  Widget _buildCurrentStepContent({
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    switch (_currentStep) {
      case ImportWizardStep.selectFile:
        return _buildSelectFileStep(isDark, cardBg, border, textPrimary, textSecondary);
      case ImportWizardStep.mapColumns:
        return _buildMapColumnsStep(isDark, cardBg, border, textPrimary, textSecondary);
      case ImportWizardStep.previewValidate:
        return _buildPreviewValidateStep(isDark, cardBg, border, textPrimary, textSecondary);
      case ImportWizardStep.importing:
        return _buildImportingStep(isDark, cardBg, border, textPrimary, textSecondary);
      case ImportWizardStep.summary:
        return _buildSummaryStep(isDark, cardBg, border, textPrimary, textSecondary);
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: SELECT FILE & TEMPLATE
  // ---------------------------------------------------------------------------

  Widget _buildSelectFileStep(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag & Drop / Tap to Upload Card
          InkWell(
            onTap: _isParsing ? null : _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFile != null ? AppTheme.primaryGreen : border,
                  width: _selectedFile != null ? 2 : 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: _isParsing
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(
                            Icons.upload_file_rounded,
                            size: 36,
                            color: AppTheme.primaryGreen,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isParsing
                        ? 'Analyzing CSV & Cross-Referencing Products...'
                        : (_selectedFile != null ? _selectedFile!.name : 'Select or Browse CSV File'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedFile != null
                        ? '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB • Click to choose another file'
                        : 'Supports Excel exports, Keells/Cargills lists, QuickBooks, Shopify (auto-detects delimiters)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _isParsing ? null : _pickFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: Text(_selectedFile != null ? 'Change File' : 'Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Download Sample Template banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.table_chart_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need a template for your store?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Download our pre-formatted CSV template with Sinhala & English items (Excel BOM compatible).',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _downloadSampleCsv,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Sample CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: MAP COLUMNS
  // ---------------------------------------------------------------------------

  Widget _buildMapColumnsStep(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    if (_previewData == null) {
      return const Center(child: Text('No CSV data available'));
    }

    final headers = _previewData!.headers;
    final hasName = _columnMapping.values.contains(CsvColumnType.name);
    final hasPrice = _columnMapping.values.contains(CsvColumnType.sellingPrice);

    return Column(
      children: [
        // Top instruction banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirm which CSV column corresponds to each product field in QuickBill.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scrollable mapping rows
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: headers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, colIndex) {
              final headerName = headers[colIndex];
              final currentType = _columnMapping[colIndex] ?? CsvColumnType.ignore;

              // Sample value preview for this column
              final sampleValues = _previewData!.sampleRows
                  .where((r) => colIndex < r.length)
                  .map((r) => r[colIndex].toString())
                  .where((v) => v.trim().isNotEmpty)
                  .take(2)
                  .join('  •  ');

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: currentType != CsvColumnType.ignore
                        ? AppTheme.primaryGreen.withValues(alpha: 0.5)
                        : border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Column index indicator
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${colIndex + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Header name & sample data preview
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerName.isNotEmpty ? headerName : 'Column ${colIndex + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          if (sampleValues.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Sample: $sampleValues',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Arrow
                    Icon(Icons.arrow_forward_rounded, size: 16, color: textSecondary),
                    const SizedBox(width: 14),

                    // Dropdown Mapping Selector
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: scaffoldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CsvColumnType>(
                            value: currentType,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            items: CsvColumnType.values.map((type) {
                              return DropdownMenuItem<CsvColumnType>(
                                value: type,
                                child: Row(
                                  children: [
                                    Icon(
                                      type.icon,
                                      size: 16,
                                      color: type == CsvColumnType.ignore
                                          ? textSecondary
                                          : AppTheme.primaryGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        type.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: type.isRequired ? FontWeight.bold : FontWeight.normal,
                                          color: type == CsvColumnType.ignore ? textSecondary : textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (type.isRequired)
                                      Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.errorRed.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'REQ',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newType) {
                              if (newType != null) {
                                setState(() {
                                  _columnMapping[colIndex] = newType;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(top: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _currentStep = ImportWizardStep.selectFile);
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              if (!hasName || !hasPrice)
                Expanded(
                  child: Text(
                    !hasName
                        ? 'Please map a column for Product Name'
                        : 'Please map a column for Selling Price',
                    style: const TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                )
              else
                const Spacer(),
              ElevatedButton.icon(
                onPressed: (!hasName || !hasPrice || _isParsing) ? null : _applyColumnMappingAndValidate,
                icon: _isParsing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Validate & Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: PREVIEW & VALIDATION (THE 10X FEATURE)
  // ---------------------------------------------------------------------------

  Widget _buildPreviewValidateStep(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_previewData == null) {
      return const Center(child: Text('No preview data'));
    }

    final p = _previewData!;
    final validToImport = p.validCount + p.warningCount;

    // Filter parsed rows
    final filteredRows = p.parsedRows.where((row) {
      // Status filter
      if (_previewFilter == 'valid' && (row.status == CsvRowValidationStatus.error || row.isExisting)) {
        return false;
      }
      if (_previewFilter == 'existing' && !row.isExisting) {
        return false;
      }
      if (_previewFilter == 'errors' && row.status != CsvRowValidationStatus.error) {
        return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = row.product.name.toLowerCase().contains(q);
        final matchSinhala = row.product.nameSinhala?.toLowerCase().contains(q) ?? false;
        final matchBarcode = row.product.baseBarcode?.toLowerCase().contains(q) ?? false;
        final matchCategory = row.product.category?.toLowerCase().contains(q) ?? false;
        return matchName || matchSinhala || matchBarcode || matchCategory;
      }

      return true;
    }).toList();

    return Column(
      children: [
        // ── 1. KPI Metric Summary Cards ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              _buildMetricChip(
                label: 'Ready to Import',
                count: p.newCount,
                color: const Color(0xFF10B981),
                icon: Icons.check_circle_rounded,
                isSelected: _previewFilter == 'valid',
                onTap: () => setState(() => _previewFilter = _previewFilter == 'valid' ? 'all' : 'valid'),
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                label: 'Existing in POS',
                count: p.existingCount,
                color: const Color(0xFF3B82F6),
                icon: Icons.sync_rounded,
                isSelected: _previewFilter == 'existing',
                onTap: () => setState(() => _previewFilter = _previewFilter == 'existing' ? 'all' : 'existing'),
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                label: 'Warnings',
                count: p.warningCount,
                color: const Color(0xFFF59E0B),
                icon: Icons.warning_amber_rounded,
                isSelected: false,
                onTap: null,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                label: 'Errors (Skipped)',
                count: p.errorCount,
                color: const Color(0xFFEF4444),
                icon: Icons.cancel_rounded,
                isSelected: _previewFilter == 'errors',
                onTap: () => setState(() => _previewFilter = _previewFilter == 'errors' ? 'all' : 'errors'),
              ),
            ],
          ),
        ),

        // ── 2. Conflict Strategy & Barcode Settings ──
        Container(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Conflict Strategy for Existing Products (${p.existingCount} matched)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Segmented Choice
              Row(
                children: [
                  Expanded(
                    child: _buildStrategyButton(
                      strategy: ImportConflictStrategy.updateAndAddStock,
                      current: _conflictStrategy,
                      label: 'Restock & Update Price',
                      sublabel: 'Add CSV qty to stock + update price',
                      onSelect: (s) => setState(() => _conflictStrategy = s),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStrategyButton(
                      strategy: ImportConflictStrategy.overwrite,
                      current: _conflictStrategy,
                      label: 'Overwrite All',
                      sublabel: 'Replace existing with CSV values',
                      onSelect: (s) => setState(() => _conflictStrategy = s),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStrategyButton(
                      strategy: ImportConflictStrategy.skipExisting,
                      current: _conflictStrategy,
                      label: 'Skip Existing',
                      sublabel: 'Only insert new products',
                      onSelect: (s) => setState(() => _conflictStrategy = s),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Auto-generate barcodes switch
              Row(
                children: [
                  Switch(
                    value: _autoGenerateBarcodes,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => setState(() => _autoGenerateBarcodes = val),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-generate unique barcodes for items without one',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── 3. Search & Filter Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: TextStyle(fontSize: 13, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search items in preview...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Showing ${filteredRows.length} of ${p.parsedRows.length}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),

        // ── 4. Filtered Preview Item List ──
        Expanded(
          child: filteredRows.isEmpty
              ? Center(
                  child: Text(
                    'No products match the selected filter',
                    style: TextStyle(color: textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: filteredRows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final item = filteredRows[idx];
                    return _buildPreviewRowCard(
                      item: item,
                      isDark: isDark,
                      cardBg: cardBg,
                      border: border,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    );
                  },
                ),
        ),

        // ── 5. Bottom Import Action Bar ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(top: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _currentStep = ImportWizardStep.mapColumns);
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Edit Mapping'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: validToImport == 0 ? null : _startImport,
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text('Import $validToImport Products Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.25),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyButton({
    required ImportConflictStrategy strategy,
    required ImportConflictStrategy current,
    required String label,
    required String sublabel,
    required ValueChanged<ImportConflictStrategy> onSelect,
  }) {
    final isSelected = strategy == current;
    return InkWell(
      onTap: () => onSelect(strategy),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 14,
                  color: isSelected ? AppTheme.primaryGreen : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryGreen : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRowCard({
    required CsvParsedRow item,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final statusColor = item.status.color;
    final isExisting = item.isExisting;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.status == CsvRowValidationStatus.error
              ? AppTheme.errorRed.withValues(alpha: 0.5)
              : border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Row Number
              Text(
                '#${item.rowIndex}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 8),

              // Product Name & Sinhala
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name.isNotEmpty ? item.product.name : '(Unnamed Product)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: item.product.name.isNotEmpty ? textPrimary : AppTheme.errorRed,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.product.nameSinhala != null)
                      Text(
                        item.product.nameSinhala!,
                        style: GoogleFonts.notoSansSinhala(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Price badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rs. ${item.product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isExisting
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                      : statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isExisting ? 'Existing' : item.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isExisting ? const Color(0xFF3B82F6) : statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Metadata row (Barcode, Stock, Cost, Category)
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildSmallMeta(
                icon: Icons.qr_code_rounded,
                text: item.product.baseBarcode ?? (item.hasError ? 'No Barcode' : 'Auto-Gen Barcode'),
                color: item.product.baseBarcode != null ? textSecondary : AppTheme.primaryGreen,
              ),
              _buildSmallMeta(
                icon: Icons.inventory_2_outlined,
                text: 'Stock: ${item.product.stock} ${item.product.unit}',
                color: textSecondary,
              ),
              if (item.product.costPrice != null)
                _buildSmallMeta(
                  icon: Icons.payments_outlined,
                  text: 'Cost: Rs. ${item.product.costPrice!.toStringAsFixed(2)}',
                  color: textSecondary,
                ),
              _buildSmallMeta(
                icon: Icons.category_outlined,
                text: item.product.category ?? 'General',
                color: textSecondary,
              ),
            ],
          ),

          // Error / Warning Callouts
          if (item.errorMessages.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...item.errorMessages.map(
              (msg) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.errorRed),
                    const SizedBox(width: 4),
                    Text(
                      msg,
                      style: const TextStyle(fontSize: 11, color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (item.warningMessages.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...item.warningMessages.map(
              (msg) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      msg,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallMeta({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 4: ANIMATED IMPORT PROGRESS
  // ---------------------------------------------------------------------------

  Widget _buildImportingStep(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    final progress = _importProgress;
    final pct = progress?.progress ?? 0.0;
    final processed = progress?.processed ?? 0;
    final total = progress?.total ?? 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular percentage
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 8,
                    backgroundColor: border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                  ),
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Importing Inventory...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Processing $processed of $total products',
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Text(
                progress?.currentName ?? 'Starting bulk database transaction...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 5: COMPLETION SUMMARY & CALL TO ACTION
  // ---------------------------------------------------------------------------

  Widget _buildSummaryStep(
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    final summary = _importSummary;
    if (summary == null) return const Center(child: Text('Done'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // Celebration Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 56,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Import Completed Successfully!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Processed ${summary.totalProcessed} products in ${summary.duration.inSeconds}.${(summary.duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 24),

          // Result KPI Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildSummaryResultCard(
                  title: 'New Added',
                  count: summary.newCreated,
                  color: const Color(0xFF10B981),
                  icon: Icons.add_circle_outline_rounded,
                  cardBg: cardBg,
                  border: border,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryResultCard(
                  title: 'Updated / Merged',
                  count: summary.existingUpdated,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.sync_rounded,
                  cardBg: cardBg,
                  border: border,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryResultCard(
                  title: 'Skipped',
                  count: summary.skipped,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.skip_next_rounded,
                  cardBg: cardBg,
                  border: border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Done Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.inventory_2_rounded, size: 20),
              label: const Text('View Updated Stock in Inventory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryResultCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required Color cardBg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
