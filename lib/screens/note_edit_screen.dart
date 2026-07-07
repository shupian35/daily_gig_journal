import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../l10n/app_localizations.dart';
import '../models/work_entry.dart';
import '../widgets/note_form_fields.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/image_gallery_viewer.dart';
import '../widgets/image_file_embed_builder.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

/// 笔记编辑/查看页 —— 精致杂志风
class NoteEditScreen extends ConsumerStatefulWidget {
  final String dateStr;
  final int? noteId;

  const NoteEditScreen({super.key, required this.dateStr, this.noteId});

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  final _titleController = TextEditingController();
  final _workLocationController = TextEditingController();
  final _contactController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _hourlyWageController = TextEditingController();
  final _workHoursController = TextEditingController();
  final _dailyWageController = TextEditingController();

  late quill.QuillController _quillController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAutoUpdating = false; // 防递归守卫
  int? _existingNoteId;
  final ImagePicker _imagePicker = ImagePicker();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    _loadNote();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _workLocationController.dispose();
    _contactController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _hourlyWageController.dispose();
    _workHoursController.dispose();
    _dailyWageController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    try {
      final db = ref.read(databaseHelperProvider);
      WorkEntry? note;

      if (widget.noteId != null) {
        note = await db.getNoteById(widget.noteId!);
      } else {
        note = null;
      }

      setState(() {
        _isLoading = false;
        if (note != null) {
          _existingNoteId = note.id;
          _titleController.text = note.title;
          _workLocationController.text = note.workLocation;
          _contactController.text = note.contact;
          _startTimeController.text = note.startTime;
          _endTimeController.text = note.endTime;
          _hourlyWageController.text =
              note.hourlyWage > 0 ? note.hourlyWage.toString() : '';
          _workHoursController.text =
              note.workHours > 0 ? note.workHours.toString() : '';
          _dailyWageController.text =
              note.dailyWage > 0 ? note.dailyWage.toString() : '';
          try {
            final deltaJson = jsonDecode(note.noteContent);
            _quillController.dispose();
            _quillController = quill.QuillController(
              document: quill.Document.fromJson(deltaJson),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (_) {
            _quillController.dispose();
            _quillController = quill.QuillController.basic();
          }
        } else {
          _existingNoteId = null;
          _startTimeController.text = '09:00';
          _endTimeController.text = '18:00';
        }
        _initialized = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.loadNoteFailed}: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _saveNote() async {
    if (!_initialized) return;

    setState(() => _isSaving = true);

    try {
      final hourlyWage = double.tryParse(_hourlyWageController.text) ?? 0.0;
      final workHours = double.tryParse(_workHoursController.text) ?? 0.0;
      final dailyWage = double.tryParse(_dailyWageController.text) ?? 0.0;

      final quillJson =
          jsonEncode(_quillController.document.toDelta().toJson());

      final note = WorkEntry(
        id: _existingNoteId,
        date: widget.dateStr,
        title: _titleController.text.trim(),
        workLocation: _workLocationController.text.trim(),
        contact: _contactController.text.trim(),
        startTime: _startTimeController.text,
        endTime: _endTimeController.text,
        hourlyWage: hourlyWage,
        workHours: workHours,
        dailyWage: dailyWage,
        noteContent: quillJson,
      );

      await ref.read(saveNoteProvider(note).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.saveSuccess),
            backgroundColor: AppConstants.incomeGreen,
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.saveFailed}: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteNote() async {
    if (_existingNoteId == null) return;

    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(
          '确定要删除 ${Helpers.toDisplayDate(widget.dateStr, locale)} 的工作笔记吗？\n此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.dangerRed,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(
        deleteNoteProvider(
          (id: _existingNoteId!, date: widget.dateStr),
        ).future,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleted),
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.deleteFailed}: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  void _autoCalculateDailyWage() {
    if (_isAutoUpdating) return;
    _isAutoUpdating = true;
    final hourlyWage = double.tryParse(_hourlyWageController.text) ?? 0.0;
    final workHours = double.tryParse(_workHoursController.text) ?? 0.0;
    final dailyWage = hourlyWage * workHours;
    _dailyWageController.text = dailyWage.toStringAsFixed(1);
    _isAutoUpdating = false;
  }

  void _autoCalculateHourlyWage() {
    if (_isAutoUpdating) return;
    _isAutoUpdating = true;
    final dailyWage = double.tryParse(_dailyWageController.text) ?? 0.0;
    final workHours = double.tryParse(_workHoursController.text) ?? 0.0;
    if (workHours > 0) {
      final hourlyWage = dailyWage / workHours;
      _hourlyWageController.text = hourlyWage.toStringAsFixed(1);
    }
    _isAutoUpdating = false;
  }

  void _autoCalculateWorkHours() {
    final hours = Helpers.calculateWorkHours(
      _startTimeController.text,
      _endTimeController.text,
    );
    _workHoursController.text = hours.toString();
    _autoCalculateDailyWage();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        await _insertImageToNote(image.path);
      }
    } catch (e) {
      _showError('${AppLocalizations.of(context)!.selectImageFailed}: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (photo != null) {
        await _insertImageToNote(photo.path);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('denied') ||
          msg.contains('permission') ||
          msg.contains('not authorized')) {
        _showError(AppLocalizations.of(context)!.cameraPermissionError);
      } else {
        _showError(AppLocalizations.of(context)!.takePhotoFailed);
      }
    }
  }

  Future<void> _insertImageToNote(String sourcePath) async {
    try {
      final imagesDir = await Helpers.getImagesDirectory();
      final fileName = 'img_${Helpers.generateImageFileName()}';
      final destPath = p.join(imagesDir.path, fileName);
      await File(sourcePath).copy(destPath);

      final selection = _quillController.selection;
      final offset = (selection.isValid && selection.baseOffset >= 0)
          ? selection.baseOffset
          : _quillController.document.length - 1;

      _quillController.replaceText(
        offset,
        0,
        quill.BlockEmbed.image(destPath),
        null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.imageInserted),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showError('${AppLocalizations.of(context)!.insertImageFailed}: $e');
    }
  }

  void _openDrawingCanvas() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DrawingScreen(
          onSave: (imagePath, includeBackground) {
            _insertImageToNote(imagePath);
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final date = Helpers.parseDate(widget.dateStr);
    final displayDate =
        date != null ? Helpers.toDisplayDate(widget.dateStr, locale) : widget.dateStr;
    final weekday = date != null ? Helpers.getWeekday(date, locale) : '';
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final hideIncome = ref.watch(hideIncomeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayDate),
              if (weekday.isNotEmpty)
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppConstants.textSecondaryDark
                        : AppConstants.textSecondary,
                  ),
                ),
            ],
          ),
          actions: [
            if (_existingNoteId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppConstants.dangerRed),
                tooltip: l10n.deleteNote,
                onPressed: _isSaving ? null : _deleteNote,
              ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_rounded,
                      color: AppConstants.incomeGreen),
              tooltip: l10n.save,
              onPressed: (_isSaving || _isLoading) ? null : _saveNote,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : isTablet
                ? _buildTabletLayout(hideIncome)
                : _buildPhoneLayout(hideIncome),
      ),
    );
  }

  Widget _buildTabletLayout(bool hideIncome) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildFormCard(hideIncome),
          ),
        ),
        Container(
          width: 0.5,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3A3A44)
              : const Color(0xFFEDE8E2),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRichTextCard(),
                const SizedBox(height: 12),
                _buildImageList(),
                const SizedBox(height: 12),
                _buildInsertButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneLayout(bool hideIncome) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(hideIncome),
          const SizedBox(height: 16),
          _buildRichTextCard(),
          const SizedBox(height: 12),
          _buildImageList(),
          const SizedBox(height: 12),
          _buildInsertButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool hideIncome) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: NoteFormFields(
          titleController: _titleController,
          workLocationController: _workLocationController,
          contactController: _contactController,
          startTimeController: _startTimeController,
          endTimeController: _endTimeController,
          hourlyWageController: _hourlyWageController,
          workHoursController: _workHoursController,
          dailyWageController: _dailyWageController,
          onAutoCalculate: _autoCalculateDailyWage,
          onDailyWageChanged: _autoCalculateHourlyWage,
          onTimeChanged: _autoCalculateWorkHours,
          hideIncome: hideIncome,
        ),
      ),
    );
  }

  Widget _buildRichTextCard() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 18, color: AppConstants.primaryDark),
                const SizedBox(width: 8),
                Text(
                  l10n.remarks,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            quill.QuillSimpleToolbar(
              controller: _quillController,
              config: const quill.QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: false,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showQuote: true,
                showCodeBlock: false,
                showSearchButton: false,
                showColorButton: true,
                showBackgroundColorButton: false,
                showClearFormat: true,
                showLink: false,
                showUndo: true,
                showRedo: true,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFE5DFD8),
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFFBFAF7),
              ),
              constraints:
                  const BoxConstraints(minHeight: 200, maxHeight: 400),
              child: quill.QuillEditor.basic(
                controller: _quillController,
                config: quill.QuillEditorConfig(
                  placeholder: l10n.remarksPlaceholder,
                  padding: const EdgeInsets.all(14),
                  autoFocus: false,
                  scrollable: true,
                  embedBuilders: [ImageFileEmbedBuilder()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsertButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildInsertButton(
          icon: Icons.photo_library_rounded,
          label: l10n.galleryImage,
          onTap: _pickImageFromGallery,
        ),
        const SizedBox(width: 10),
        _buildInsertButton(
          icon: Icons.camera_alt_rounded,
          label: l10n.takePhoto,
          onTap: _takePhoto,
        ),
        const SizedBox(width: 10),
        _buildInsertButton(
          icon: Icons.draw_rounded,
          label: l10n.drawingBoard,
          onTap: _openDrawingCanvas,
        ),
      ],
    );
  }

  Widget _buildInsertButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262630) : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          ),
          boxShadow: AppConstants.cardShadow(isDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppConstants.primaryDark, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppConstants.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageList() {
    final l10n = AppLocalizations.of(context)!;
    final images = _collectAllImages();
    if (images.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
          width: 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library_rounded,
                    size: 16, color: AppConstants.primaryDark),
                const SizedBox(width: 6),
                Text(
                  '${l10n.images} (${images.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (images.length > 1)
                  Text(
                    l10n.tapToViewFullImage,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppConstants.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ImageGalleryViewer(
                                images: images,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSm),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF3A3A44)
                                    : const Color(0xFFE5DFD8),
                              ),
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSm),
                            ),
                            child: Image.file(
                              File(images[index]),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_rounded,
                                      size: 32),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 3,
                        right: 3,
                        child: GestureDetector(
                          onTap: () => _removeImageFromDocument(images[index]),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: AppConstants.dangerRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _collectAllImages() {
    final images = <String>[];
    try {
      final deltaJson = _quillController.document.toDelta().toJson();
      for (final op in deltaJson) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          images.add(insert['image'] as String);
        }
      }
    } catch (_) {}
    return images;
  }

  void _removeImageFromDocument(String imagePath) {
    try {
      final delta = _quillController.document.toDelta();
      final ops = delta.toJson();
      int offset = 0;
      for (final op in ops) {
        final imgInsert = op['insert'];
        if (imgInsert is Map && imgInsert.containsKey('image')) {
          if (imgInsert['image'] == imagePath) {
            _quillController.replaceText(offset, 2, '', null);
            setState(() {});
            return;
          }
        }
        final ins = op['insert'];
        if (ins is String) {
          offset += ins.length;
        } else if (ins is Map) {
          offset += 1;
        }
      }
    } catch (_) {}
  }
}

