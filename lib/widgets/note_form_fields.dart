import 'package:flutter/material.dart';
import '../utils/helpers.dart';

/// 笔记结构化字段表单组件
/// 包含：工作标题、工作地点、工作时间段、时薪、工作时长、日工资
class NoteFormFields extends StatelessWidget {
  // 控制器
  final TextEditingController titleController;
  final TextEditingController workLocationController;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final TextEditingController hourlyWageController;
  final TextEditingController workHoursController;
  final TextEditingController dailyWageController;

  /// 当时长或时薪变化时，自动计算日工资的回调
  final VoidCallback? onAutoCalculate;
  /// 时间变化时的回调
  final VoidCallback? onTimeChanged;

  const NoteFormFields({
    super.key,
    required this.titleController,
    required this.workLocationController,
    required this.startTimeController,
    required this.endTimeController,
    required this.hourlyWageController,
    required this.workHoursController,
    required this.dailyWageController,
    this.onAutoCalculate,
    this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 工作标题
        _buildFieldLabel('工作标题'),
        TextFormField(
          controller: titleController,
          decoration: _inputDecoration('例如：会展协助、发传单、家教'),
        ),
        const SizedBox(height: 16),

        // 工作地点
        _buildFieldLabel('工作地点'),
        TextFormField(
          controller: workLocationController,
          decoration: _inputDecoration('例如：会展中心A馆、解放路步行街'),
        ),
        const SizedBox(height: 16),

        // 工作时间段
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('开始时间'),
                  TextFormField(
                    controller: startTimeController,
                    readOnly: true,
                    decoration: _inputDecoration('09:00'),
                    onTap: () => _pickTime(context, startTimeController,
                        onChanged: onTimeChanged),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('—', style: TextStyle(fontSize: 20, color: Colors.grey)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('结束时间'),
                  TextFormField(
                    controller: endTimeController,
                    readOnly: true,
                    decoration: _inputDecoration('18:00'),
                    onTap: () => _pickTime(context, endTimeController,
                        onChanged: onTimeChanged),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 时薪 & 工作时长
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('时薪 (¥)'),
                  TextFormField(
                    controller: hourlyWageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('0.00'),
                    onChanged: (_) => onAutoCalculate?.call(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('工作时长 (h)'),
                  TextFormField(
                    controller: workHoursController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('0.0'),
                    onChanged: (_) => onAutoCalculate?.call(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 日工资（自动计算 + 可手动覆盖）
        _buildFieldLabel('日工资 (¥)'),
        TextFormField(
          controller: dailyWageController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration('0.00').copyWith(
            helperText: '时薪 × 时长自动计算，也可手动修改',
            helperStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  /// 字段标签
  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// 统一样式的输入框装饰
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  /// 时间选择器
  Future<void> _pickTime(
    BuildContext context,
    TextEditingController controller, {
    VoidCallback? onChanged,
  }) async {
    // 解析当前时间
    final currentParts = Helpers.parseTime(controller.text);
    final initialTime = TimeOfDay(
      hour: currentParts['hour']!,
      minute: currentParts['minute']!,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.text = formatted;
      onChanged?.call();
    }
  }
}
