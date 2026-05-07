/// 工作笔记数据模型
/// 对应数据库 work_notes 表
class WorkNote {
  final int? id;
  final String date;       // 日期，格式 YYYY-MM-DD
  final String title;      // 工作标题，如"会展协助"
  final String workLocation; // 工作地点
  final String startTime;  // 开始时间，格式 HH:mm
  final String endTime;    // 结束时间，格式 HH:mm
  final double hourlyWage; // 时薪
  final double workHours;  // 工作时长（小时）
  final double dailyWage;  // 日工资
  final String noteContent;// 富文本内容，存储 Quill Delta JSON 字符串
  final String? createdAt;
  final String? updatedAt;

  const WorkNote({
    this.id,
    required this.date,
    required this.title,
    required this.workLocation,
    required this.startTime,
    required this.endTime,
    required this.hourlyWage,
    required this.workHours,
    required this.dailyWage,
    required this.noteContent,
    this.createdAt,
    this.updatedAt,
  });

  /// 从数据库 Map 创建 WorkNote 实例
  factory WorkNote.fromMap(Map<String, dynamic> map) {
    return WorkNote(
      id: map['id'] as int?,
      date: map['date'] as String,
      title: (map['title'] as String?) ?? '',
      workLocation: (map['work_location'] as String?) ?? '',
      startTime: (map['start_time'] as String?) ?? '09:00',
      endTime: (map['end_time'] as String?) ?? '18:00',
      hourlyWage: (map['hourly_wage'] as num?)?.toDouble() ?? 0.0,
      workHours: (map['work_hours'] as num?)?.toDouble() ?? 0.0,
      dailyWage: (map['daily_wage'] as num?)?.toDouble() ?? 0.0,
      noteContent: (map['note_content'] as String?) ?? '[]',
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
      'start_time': startTime,
      'end_time': endTime,
      'hourly_wage': hourlyWage,
      'work_hours': workHours,
      'daily_wage': dailyWage,
      'note_content': noteContent,
      if (!forUpdate) 'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (forUpdate) {
      // 更新时不覆盖 id
    }
    return map;
  }

  /// 创建一份默认的空笔记模板（用于新建）
  factory WorkNote.empty(String date) {
    return WorkNote(
      date: date,
      title: '',
      workLocation: '',
      startTime: '09:00',
      endTime: '18:00',
      hourlyWage: 0.0,
      workHours: 9.0,
      dailyWage: 0.0,
      noteContent: '[]',
    );
  }

  /// 复制并修改部分字段
  WorkNote copyWith({
    int? id,
    String? date,
    String? title,
    String? workLocation,
    String? startTime,
    String? endTime,
    double? hourlyWage,
    double? workHours,
    double? dailyWage,
    String? noteContent,
    String? createdAt,
    String? updatedAt,
  }) {
    return WorkNote(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      workLocation: workLocation ?? this.workLocation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      workHours: workHours ?? this.workHours,
      dailyWage: dailyWage ?? this.dailyWage,
      noteContent: noteContent ?? this.noteContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'WorkNote(id: $id, date: $date, title: $title, dailyWage: $dailyWage)';
}
