/// 工作笔记数据模型
/// 对应数据库 work_notes 表
class WorkEntry {
  final int? id;
  final String date;       // 日期，格式 YYYY-MM-DD
  final String title;      // 工作标题，如"会展协助"
  final String workLocation; // 工作地点
  final String contact;    // 对接人
  final String startTime;  // 开始时间，格式 HH:mm
  final String endTime;    // 结束时间，格式 HH:mm
  final double hourlyWage; // 时薪
  final double workHours;  // 工作时长（小时）
  final double dailyWage;  // 日工资
  final String noteContent;// 富文本内容，存储 Quill Delta JSON 字符串
  final List<String> tags; // 标签，逗号分隔字符串反序列化结果
  final String? createdAt;
  final String? updatedAt;

  const WorkEntry({
    this.id,
    required this.date,
    required this.title,
    required this.workLocation,
    required this.contact,
    required this.startTime,
    required this.endTime,
    required this.hourlyWage,
    required this.workHours,
    required this.dailyWage,
    required this.noteContent,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// 从数据库 Map 创建 WorkEntry 实例
  factory WorkEntry.fromMap(Map<String, dynamic> map) {
    final tagsStr = (map['tags'] as String?) ?? '';
    return WorkEntry(
      id: map['id'] as int?,
      date: map['date'] as String,
      title: (map['title'] as String?) ?? '',
      workLocation: (map['work_location'] as String?) ?? '',
      contact: (map['contact'] as String?) ?? '',
      startTime: (map['start_time'] as String?) ?? '09:00',
      endTime: (map['end_time'] as String?) ?? '18:00',
      hourlyWage: (map['hourly_wage'] as num?)?.toDouble() ?? 0.0,
      workHours: (map['work_hours'] as num?)?.toDouble() ?? 0.0,
      dailyWage: (map['daily_wage'] as num?)?.toDouble() ?? 0.0,
      noteContent: (map['note_content'] as String?) ?? '[]',
      tags: _decodeTags(tagsStr),
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap({bool forUpdate = false}) {
    final map = <String, dynamic>{
      'date': date,
      'title': title,
      'work_location': workLocation,
      'contact': contact,
      'start_time': startTime,
      'end_time': endTime,
      'hourly_wage': hourlyWage,
      'work_hours': workHours,
      'daily_wage': dailyWage,
      'note_content': noteContent,
      'tags': _encodeTags(tags),
      if (!forUpdate) 'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    return map;
  }

  /// 创建一份默认的空笔记模板（用于新建）
  factory WorkEntry.empty(String date) {
    return WorkEntry(
      date: date,
      title: '',
      workLocation: '',
      contact: '',
      startTime: '09:00',
      endTime: '18:00',
      hourlyWage: 0.0,
      workHours: 9.0,
      dailyWage: 0.0,
      noteContent: '[]',
    );
  }

  /// 复制并修改部分字段
  WorkEntry copyWith({
    int? id,
    String? date,
    String? title,
    String? workLocation,
    String? contact,
    String? startTime,
    String? endTime,
    double? hourlyWage,
    double? workHours,
    double? dailyWage,
    String? noteContent,
    List<String>? tags,
    String? createdAt,
    String? updatedAt,
  }) {
    return WorkEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      workLocation: workLocation ?? this.workLocation,
      contact: contact ?? this.contact,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      workHours: workHours ?? this.workHours,
      dailyWage: dailyWage ?? this.dailyWage,
      noteContent: noteContent ?? this.noteContent,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'WorkEntry(id: $id, date: $date, title: $title, dailyWage: $dailyWage, tags: $tags)';

  // ── tags 编解码（逗号分隔字符串；与 DB 列 tags TEXT 对应）──

  /// 列表 → 逗号分隔字符串。
  /// 空列表返回 ''，避免写入 `'null'` 或多余分隔符。
  static String _encodeTags(List<String> tags) {
    if (tags.isEmpty) return '';
    return tags.map((t) => t.trim()).where((t) => t.isNotEmpty).join(',');
  }

  /// 逗号分隔字符串 → 列表。
  /// 兼容老数据(列不存在或 NULL 已被 caller 预转 '')和畸形输入。
  static List<String> _decodeTags(String raw) {
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }

  /// 暴露给外部序列化（导出 JSON 用）。
  String get tagsString => _encodeTags(tags);

  /// 暴露给外部解析（导入 / 搜索结果显示用）。
  static List<String> parseTags(String raw) => _decodeTags(raw);
}