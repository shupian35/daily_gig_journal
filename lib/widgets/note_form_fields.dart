import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

/// 笔记结构化字段表单组件 —— 精致杂志风
class NoteFormFields extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController workLocationController;
  final TextEditingController contactController;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final TextEditingController hourlyWageController;
  final TextEditingController workHoursController;
  final TextEditingController dailyWageController;
  final VoidCallback? onAutoCalculate;
  final VoidCallback? onDailyWageChanged;
  final VoidCallback? onTimeChanged;
  final bool hideIncome;

  const NoteFormFields({
    super.key,
    required this.titleController,
    required this.workLocationController,
    required this.contactController,
    required this.startTimeController,
    required this.endTimeController,
    required this.hourlyWageController,
    required this.workHoursController,
    required this.dailyWageController,
    this.onAutoCalculate,
    this.onDailyWageChanged,
    this.onTimeChanged,
    this.hideIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionSpacing = const SizedBox(height: 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 基本信息 ──
        _buildSectionHeader(l10n.basicInfo, Icons.work_outline_rounded),
        const SizedBox(height: 14),
        _buildFieldLabel(l10n.workTitle),
        const SizedBox(height: 6),
        TextFormField(
          controller: titleController,
          decoration: _inputDecoration(l10n.workTitleHint),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel(l10n.workLocation),
        const SizedBox(height: 6),
        TextFormField(
          controller: workLocationController,
          decoration: _inputDecoration(l10n.workLocationHint),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel(l10n.contactPerson),
        const SizedBox(height: 6),
        TextFormField(
          controller: contactController,
          decoration: _inputDecoration(l10n.contactPersonHint),
        ),

        sectionSpacing,

        // ── 工作时间 ──
        _buildSectionHeader(l10n.workTime, Icons.access_time_rounded),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(l10n.startTime),
                  const SizedBox(height: 6),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF3A3A44)
                          : const Color(0xFFF0EBE4),
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppConstants.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(l10n.endTime),
                  const SizedBox(height: 6),
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

        if (!hideIncome) ...[
          sectionSpacing,
          // ── 收入详情 ──
          _buildSectionHeader(l10n.incomeDetails, Icons.payments_outlined),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel(l10n.hourlyRate),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: hourlyWageController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                    _buildFieldLabel(l10n.workHours),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: workHoursController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration('0.0'),
                      onChanged: (_) => onAutoCalculate?.call(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(l10n.dailyWage),
          const SizedBox(height: 6),
          TextFormField(
            controller: dailyWageController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration('0.00').copyWith(
              helperText: l10n.wageHelperText,
              helperStyle: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
            ),
            onChanged: (_) => onDailyWageChanged?.call(),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppConstants.primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppConstants.primaryDark,
            letterSpacing: 0.3,
          ),
        ),
        const Expanded(child: SizedBox()),
        Container(
          width: 24,
          height: 1.5,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppConstants.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    TextEditingController controller, {
    VoidCallback? onChanged,
  }) async {
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
