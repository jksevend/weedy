import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Future<bool> discardChangesDialog(BuildContext context) async {
  return await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(tr('common.confirm_discard_title')),
        content: Text(tr('common.confirm_discard_description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('common.confirm')),
          ),
        ],
      );
    },
  );
}
