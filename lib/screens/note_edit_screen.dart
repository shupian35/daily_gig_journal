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

/// 笔记编辑/查看页
/// 支持新建和编辑已有笔记
/// - 如果提供了 [noteId]，则加载该条笔记进行编辑
/// - 如果 [noteId] 为 null，则为 [dateStr] 创建新笔记
class NoteEditScreen extends ConsumerStatefulWidget {
  /// 目标日期，格式 YYYY-MM-DD
  final String dateStr;
  /// 要编辑的笔记 id，为 null 表示新建
  final int? noteId;

  const NoteEditScreen({super.key, required this.dateStr, this.noteId});

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  // ============ 表单控制器 ============
  final _titleController = TextEditingController();
  final _workLocationController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _hourlyWageController = TextEditingController();
  final _workHoursController = TextEditingController();
  final _dailyWageController = TextEditingController();

  // ============ 富文本控制器 ============
  late quill.QuillController _quillController;

  // ============ 状态变量 ============
  bool _isLoading = true;
  bool _isSaving = false;
  int? _existingNoteId;
  final ImagePicker _imagePicker = ImagePicker();

  // 是否已初始化（避免重复加载）
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

  /// 从数据库加载笔记
  Future<void> _loadNote() async {
    try {
      final db = ref.read(databaseHelperProvider);
      WorkNote? note;

      if (widget.noteId != null) {
        note = await db.getNoteById(widget.noteId!);
      } else {
        note = await db.getNoteByDate(widget.dateStr);
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
          // 加载 Quill Delta 内容
          try {
            final deltaJson = jsonDecode(note.noteContent);
            _quillController = quill.QuillController(
              document: quill.Document.fromJson(deltaJson),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (_) {
            // Delta 解析失败，用空文档
            _quillController = quill.QuillController.basic();
          }
        } else {
          _existingNoteId = null;
          // 新笔记默认值
          _startTimeController.text = '09:00';
          _endTimeController.text = '18:00';
        }
        _initialized = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载笔记失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 保存笔记
  Future<void> _saveNote() async {
    if (!_initialized) return;

    setState(() => _isSaving = true);

    try {
      // 读取表单数据
      final hourlyWage = double.tryParse(_hourlyWageController.text) ?? 0.0;
      final workHours = double.tryParse(_workHoursController.text) ?? 0.0;
      final dailyWage = double.tryParse(_dailyWageController.text) ?? 0.0;

      // 序列化 Quill 文档为 JSON
      final quillJson = jsonEncode(_quillController.document.toDelta().toJson());

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

      // 通过 provider 保存
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
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 删除笔记
  Future<void> _deleteNote() async {
    if (_existingNoteId == null) return;

    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${Helpers.toDisplayDate(widget.dateStr)} 的工作笔记吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppConstants.dangerRed),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(deleteNoteProvider((id: _existingNoteId!, date: widget.dateStr)).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 自动计算日工资
  void _autoCalculateDailyWage() {
    final hourlyWage = double.tryParse(_hourlyWageController.text) ?? 0.0;
    final workHours = double.tryParse(_workHoursController.text) ?? 0.0;
    final dailyWage = hourlyWage * workHours;
    _dailyWageController.text = dailyWage.toStringAsFixed(1);
  }

  /// 自动计算工作时长
  void _autoCalculateWorkHours() {
    final hours = Helpers.calculateWorkHours(
      _startTimeController.text,
      _endTimeController.text,
    );
    _workHoursController.text = hours.toString();
    _autoCalculateDailyWage();
  }

  /// 从相册选择图片插入笔记
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

  /// 拍照插入笔记
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
        requestFullMetadata: false,
      );
      if (photo != null) {
        await _insertImageToNote(photo.path);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('denied') || msg.contains('permission') || msg.contains('not authorized')) {
        _showError('无法使用相机，请在系统设置中允许相机权限');
      } else {
        _showError('拍照失败');
      }
    }
  }

  /// 将图片复制到本地并插入 Quill 编辑器
  Future<void> _insertImageToNote(String sourcePath) async {
    try {
      final imagesDir = await Helpers.getImagesDirectory();
      final fileName = 'img_${Helpers.generateImageFileName()}';
      final destPath = p.join(imagesDir.path, fileName);
      await File(sourcePath).copy(destPath);

      // 获取当前光标位置，若无有效光标则插入到文档末尾
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
          const SnackBar(content: Text('图片已插入'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      _showError('插入图片失败: $e');
    }
  }

  /// 打开全屏画板（空白手写/画画）
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
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = Helpers.parseDate(widget.dateStr);
    final displayDate = date != null ? Helpers.toDisplayDate(widget.dateStr) : widget.dateStr;
    final weekday = date != null ? Helpers.getChineseWeekday(date) : '';
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final hideIncome = ref.watch(hideIncomeProvider);

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
              Text(weekday,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          if (_existingNoteId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppConstants.dangerRed),
              tooltip: '删除笔记',
              onPressed: _isSaving ? null : _deleteNote,
            ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: AppConstants.incomeGreen),
            tooltip: '保存',
            onPressed: _isSaving ? null : _saveNote,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isTablet
              ? _buildTabletLayout(hideIncome)
              : _buildPhoneLayout(hideIncome),
    ));
  }

  /// 平板布局：左侧表单 + 右侧备注和插入
  Widget _buildTabletLayout(bool hideIncome) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：表单
        SizedBox(
          width: 360,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildFormCard(hideIncome),
          ),
        ),
        // 中间分割线
        const VerticalDivider(width: 1),
        // 右侧：富文本 + 插入按钮
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

  /// 手机布局：原有单列滚动
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

  /// 表单卡片
  Widget _buildFormCard(bool hideIncome) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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

  /// 富文本卡片
  Widget _buildRichTextCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('备注', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
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
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
              child: quill.QuillEditor.basic(
                controller: _quillController,
                config: quill.QuillEditorConfig(
                  placeholder: '写写今天的工作内容和感受...',
                  padding: const EdgeInsets.all(12),
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

  /// 插入操作按钮组
  Widget _buildInsertButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildInsertButton(
            icon: Icons.photo_library,
            label: '相册图片',
            onTap: _pickImageFromGallery),
        _buildInsertButton(
            icon: Icons.camera_alt,
            label: '拍照',
            onTap: _takePhoto),
        _buildInsertButton(
            icon: Icons.draw,
            label: '画板',
            onTap: _openDrawingCanvas),
      ],
    );
  }

  /// 图片缩略图列表（显示备注中所有图片）
  Widget _buildImageList() {
    final images = _collectAllImages();
    if (images.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, size: 16, color: AppConstants.primaryDark),
                const SizedBox(width: 6),
                Text('图片 (${images.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (images.length > 1)
                  Text('点击可查看大图',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FullScreenGallery(
                                images: images, initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Image.file(
                              File(images[index]),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 32),
                            ),
                          ),
                        ),
                      ),
                      // 删除按钮
                      Positioned(
                        top: 0, right: 0,
                        child: GestureDetector(
                          onTap: () => _removeImageFromDocument(images[index]),
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
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

  /// 从 Quill 文档收集所有图片路径
  List<String> _collectAllImages() {
    final images = <String>[];
    try {
      final deltaJson = _quillController.document.toDelta().toJson();
      for (final op in deltaJson) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is Map && insert.containsKey('image')) {
            images.add(insert['image'] as String);
          }
        }
      }
    } catch (_) {}
    return images;
  }

  /// 从 Quill 文档中删除指定图片
  void _removeImageFromDocument(String imagePath) {
    try {
      final delta = _quillController.document.toDelta();
      final ops = delta.toJson();
      int offset = 0;
      for (final op in ops) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is Map && insert.containsKey('image')) {
            if (insert['image'] == imagePath) {
              // 删除该嵌入：先删除图片 embed(长度1)，再删除后面的换行符(长度1)
              _quillController.replaceText(offset, 2, '', null);
              setState(() {}); // 刷新图片列表
              return;
            }
          }
        }
        // 计算偏移：文本长度或嵌入对象长度为1
        if (op is Map<String, dynamic>) {
          final ins = op['insert'];
          if (ins is String) {
            offset += ins.length;
          } else if (ins is Map) {
            offset += 1; // embed
          }
        }
      }
    } catch (_) {}
  }

  /// 构建插入按钮
  Widget _buildInsertButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppConstants.primaryDark, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 图片文件嵌入渲染器（缩略图 + 点击查看大图）
class _ImageFileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final path = embedContext.node.value.data as String;

    // 收集文档中所有图片路径
    final allImages = <String>[];
    final currentIndex = _collectImages(embedContext, allImages, path);

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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 48),
                ),
                // 点击提示
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('点击放大',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 从文档 Delta JSON 中收集所有图片路径
  int _collectImages(quill.EmbedContext ctx, List<String> out, String currentPath) {
    int idx = 0;
    int foundIdx = -1;
    try {
      final deltaJson = ctx.controller.document.toDelta().toJson();
      for (final op in deltaJson) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is Map && insert.containsKey('image')) {
            final p = insert['image'] as String;
            out.add(p);
            if (p == currentPath) foundIdx = idx;
            idx++;
          }
        }
      }
    } catch (_) {}
    return foundIdx >= 0 ? foundIdx : 0;
  }
}

/// 全屏图片浏览器（支持左右翻页）
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
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 图片滑动区域
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
                      child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
          // 左箭头
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
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
          // 右箭头
          if (_currentIndex < widget.images.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
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
