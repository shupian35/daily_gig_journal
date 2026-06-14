import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/work_entry.dart';

/// 数据导出工具类
/// 支持将全部工作笔记导出为 CSV 或 JSON 文件
class ExportHelper {
  ExportHelper._();

  /// 导出格式枚举
  static const String csv = 'csv';
  static const String json = 'json';

  /// 执行导出，返回导出文件路径
  /// [format] 取值 'csv' 或 'json'
  static Future<String> exportToFile(String format) async {
    final db = DatabaseHelper();
    final notes = await db.getAllNotes();

    return switch (format) {
      csv => _exportCsv(notes),
      json => _exportJson(notes),
      _ => throw ArgumentError('不支持的导出格式: $format'),
    };
  }

  /// 导出为 CSV 文件
  static Future<String> _exportCsv(List<WorkEntry> notes) async {
    final buffer = StringBuffer();

    // BOM 头，确保 Excel 正确识别 UTF-8 中文
    buffer.write('\uFEFF');

    // 表头
    buffer.writeln(
      '编号,日期,工作标题,工作地点,开始时间,结束时间,时薪,工作时长,日工资,笔记内容,创建时间,更新时间',
    );

    // 数据行
    for (final note in notes) {
      buffer.writeln([
        note.id ?? '',
        note.date,
        _csvEscape(note.title),
        _csvEscape(note.workLocation),
        note.startTime,
        note.endTime,
        note.hourlyWage,
        note.workHours,
        note.dailyWage,
        _csvEscape(_deltaToPlainText(note.noteContent)),
        note.createdAt ?? '',
        note.updatedAt ?? '',
      ].join(','));
    }

    return _writeToTempFile(buffer.toString(), 'csv');
  }

  /// 导出为 JSON 文件
  static Future<String> _exportJson(List<WorkEntry> notes) async {
    final list = notes.map((note) => {
      'id': note.id,
      'date': note.date,
      'title': note.title,
      'work_location': note.workLocation,
      'start_time': note.startTime,
      'end_time': note.endTime,
      'hourly_wage': note.hourlyWage,
      'work_hours': note.workHours,
      'daily_wage': note.dailyWage,
      'note_content': note.noteContent,
      'created_at': note.createdAt,
      'updated_at': note.updatedAt,
    }).toList();

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(list);

    return _writeToTempFile(jsonString, 'json');
  }

  /// 写入临时文件，返回路径
  static Future<String> _writeToTempFile(
    String content,
    String extension,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
    final fileName = 'daily_gig_export_$timestamp.$extension';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    return filePath;
  }

  /// 获取导出文件名（不含路径）
  static String exportFileName(String format) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
    return 'daily_gig_export_$timestamp.$format';
  }

  // ========== 工具方法 ==========

  /// 将 Quill Delta JSON 转为可读纯文本
  static String _deltaToPlainText(String deltaJson) {
    try {
      final List<dynamic> ops = jsonDecode(deltaJson);
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map<String, dynamic>) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          } else if (insert is Map) {
            // 嵌入对象（图片等）
            if (insert.containsKey('image')) {
              buffer.write('[图片]');
            } else {
              buffer.write('[附件]');
            }
          }
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return deltaJson; // 解析失败返回原文
    }
  }

  /// CSV 字段转义：包含逗号、引号、换行时用双引号包裹
  static String _csvEscape(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// 数字补零
  static String _pad(int n) => n.toString().padLeft(2, '0');
}
