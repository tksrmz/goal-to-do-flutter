import 'package:material_ui/material_ui.dart';

import '../domain/calendar_date.dart';

/// 入力の上限（REQ-001 7.4）。
const nameMaxLength = 100;
const longTextMaxLength = 2000;

/// 日付の表示。今年なら「11/6」、それ以外は「2027/3/31」。
String formatDate(CalendarDate date, CalendarDate today) =>
    date.year == today.year
    ? '${date.month}/${date.day}'
    : '${date.year}/${date.month}/${date.day}';

/// 重要・緊急のタグ。
class PriorityTag extends StatelessWidget {
  const PriorityTag.important({super.key}) : label = '重要', _important = true;

  const PriorityTag.urgent({super.key}) : label = '緊急', _important = false;

  final String label;
  final bool _important;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = _important
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : (scheme.tertiaryContainer, scheme.onTertiaryContainer);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}

/// 確認ダイアログ。確定なら `true`。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  String cancelLabel = 'キャンセル',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 日付の入力欄。タップで日付を選ぶ。[clearable] なら空に戻せる。
class DateFormField extends FormField<CalendarDate> {
  DateFormField({
    super.key,
    required String label,
    required CalendarDate today,
    super.initialValue,
    super.validator,
    super.onSaved,
    bool clearable = false,
  }) : super(
         builder: (field) {
           final value = field.value;
           Future<void> pick() async {
             final initial = value ?? today;
             final picked = await showDatePicker(
               context: field.context,
               initialDate: initial.toLocalDateTime(),
               firstDate: DateTime(2000),
               lastDate: DateTime(2100, 12, 31),
               currentDate: today.toLocalDateTime(),
             );
             if (picked != null) {
               field.didChange(CalendarDate.fromDateTime(picked));
             }
           }

           return InkWell(
             onTap: pick,
             child: InputDecorator(
               decoration: InputDecoration(
                 labelText: label,
                 errorText: field.errorText,
                 suffixIcon: clearable && value != null
                     ? IconButton(
                         tooltip: '$labelを解除',
                         icon: const Icon(Icons.clear),
                         onPressed: () => field.didChange(null),
                       )
                     : const Icon(Icons.calendar_today),
               ),
               isEmpty: value == null,
               child: Text(value == null ? '' : formatDate(value, today)),
             ),
           );
         },
       );
}
