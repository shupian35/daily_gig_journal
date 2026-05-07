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
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photo != null) {
        await _insertImageToNote(photo.path);
      }
    } catch (e) {
      _showError('拍照失败: $e');
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

    return Scaffold(
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
    );
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
                const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
            label: '手写/画画',
            onTap: _openDrawingCanvas),
      ],
    );
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

/// 图片文件嵌入渲染器
/// 将 BlockEmbed.image 中的本地文件路径渲染为 Image.file
class _ImageFileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final path = embedContext.node.value.data as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 48),
      ),
    );
  }
}
