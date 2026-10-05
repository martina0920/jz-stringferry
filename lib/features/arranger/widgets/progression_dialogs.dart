import 'package:flutter/material.dart';

/// 重命名输入框；取消或关闭返回 null。
Future<String?> promptProgressionRename(
  BuildContext context,
  String current,
) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重命名'),
      content: TextField(
        key: const Key('rename_field'),
        controller: controller,
        autofocus: true,
        maxLength: 30,
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('rename_confirm'),
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// 删除二次确认（显示标题）。
Future<bool> confirmProgressionDelete(BuildContext context, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('删除进行「$title」？此操作不可撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('confirm_delete_progression'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// 模板替换二次确认。
Future<bool> confirmTemplateReplace(
  BuildContext context,
  String templateName,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      key: const Key('template_replace_dialog'),
      title: const Text('套用模板'),
      content: Text('套用「$templateName」将替换当前和弦序列，是否继续？'),
      actions: [
        TextButton(
          key: const Key('template_replace_cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('template_replace_confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('替换'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
