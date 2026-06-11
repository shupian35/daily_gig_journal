import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../models/work_note.dart';
import '../widgets/note_form_fields.dart';
import '../widgets/drawing_canvas.dart';
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
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _hourlyWageController = TextEditingController();
  final _workHoursController = TextEditingController();
  final _dailyWageController = TextEditingController();

  late quill.QuillController _quillController;

  bool _isLoading = true;
  bool _isSaving = false;
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
      WorkNote? note;

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
            _quillController = quill.QuillController(
              document: quill.Document.fromJson(deltaJson),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (_) {
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
            content: Text('加载笔记失败: $e'),
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

      final note = WorkNote(
        id: _existingNoteId,
        date: widget.dateStr,
        title: _titleController.text.trim(),
        workLocation: _workLocationController.text.trim(),
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
          const SnackBar(
            content: Text('保存成功！'),
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
            content: Text('保存失败: $e'),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除 ${Helpers.toDisplayDate(widget.dateStr)} 的工作笔记吗？\n此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.dangerRed,
            ),
            child: const Text('删除'),
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
          const SnackBar(
            content: Text('已删除'),
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  void _autoCalculateDailyWage() {
    final hourlyWage = double.tryParse(_hourlyWageController.text) ?? 0.0;
    final workHours = double.tryParse(_workHoursController.text) ?? 0.0;
    final dailyWage = hourlyWage * workHours;
    _dailyWageController.text = dailyWage.toStringAsFixed(1);
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
      _showError('选择图片失败: $e');
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
        _showError('无法使用相机，请在系统设置中允许相机权限');
      } else {
        _showError('拍照失败');
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
          const SnackBar(
            content: Text('图片已插入'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showError('插入图片失败: $e');
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
    final date = Helpers.parseDate(widget.dateStr);
    final displayDate =
        date != null ? Helpers.toDisplayDate(widget.dateStr) : widget.dateStr;
    final weekday = date != null ? Helpers.getChineseWeekday(date) : '';
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
                tooltip: '删除笔记',
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
              tooltip: '保存',
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
          startTimeController: _startTimeController,
          endTimeController: _endTimeController,
          hourlyWageController: _hourlyWageController,
          workHoursController: _workHoursController,
          dailyWageController: _dailyWageController,
          onAutoCalculate: _autoCalculateDailyWage,
          onTimeChanged: _autoCalculateWorkHours,
          hideIncome: hideIncome,
        ),
      ),
    );
  }

  Widget _buildRichTextCard() {
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
                const Text(
                  '备注',
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
                  placeholder: '写写今天的工作内容和感受...',
                  padding: const EdgeInsets.all(14),
                  autoFocus: false,
                  scrollable: true,
                  embedBuilders: [_ImageFileEmbedBuilder()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsertButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildInsertButton(
          icon: Icons.photo_library_rounded,
          label: '相册图片',
          onTap: _pickImageFromGallery,
        ),
        const SizedBox(width: 10),
        _buildInsertButton(
          icon: Icons.camera_alt_rounded,
          label: '拍照',
          onTap: _takePhoto,
        ),
        const SizedBox(width: 10),
        _buildInsertButton(
          icon: Icons.draw_rounded,
          label: '画板',
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
                  '图片 (${images.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (images.length > 1)
                  const Text(
                    '点击可查看大图',
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
                              builder: (_) => _FullScreenGallery(
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

/// 图片文件嵌入渲染器
class _ImageFileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final path = embedContext.node.value.data as String;
    final allImages = <String>[];
    final currentIndex = _collectImages(embedContext, allImages, path);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (allImages.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _FullScreenGallery(
                images: allImages,
                initialIndex: currentIndex,
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFE5DFD8),
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_rounded, size: 48),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXs),
                    ),
                    child: const Text(
                      '点击放大',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _collectImages(
      quill.EmbedContext ctx, List<String> out, String currentPath) {
    int idx = 0;
    int foundIdx = -1;
    try {
      final deltaJson = ctx.controller.document.toDelta().toJson();
      for (final op in deltaJson) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          final p = insert['image'] as String;
          out.add(p);
          if (p == currentPath) foundIdx = idx;
          idx++;
        }
      }
    } catch (_) {}
    return foundIdx >= 0 ? foundIdx : 0;
  }
}

/// 全屏图片浏览器
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: Image.file(
                    File(widget.images[index]),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded,
                          size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: IconButton(
                    icon:
                        const Icon(Icons.chevron_left_rounded, color: Colors.white),
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_currentIndex < widget.images.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white),
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
