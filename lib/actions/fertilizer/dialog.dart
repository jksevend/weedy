import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:weedy/actions/fertilizer/model.dart';
import 'package:weedy/actions/fertilizer/provider.dart';

Future<void> showFertilizerForm(
  BuildContext context,
  FertilizerProvider fertilizerProvider,
  Fertilizer? fertilizer,
) async {
  final TextEditingController nameController = TextEditingController(
    text: fertilizer == null ? '' : fertilizer.name,
  );
  final TextEditingController descriptionController = TextEditingController(
    text: fertilizer == null ? '' : fertilizer.description,
  );

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          fertilizer == null ? 'Add Fertilizer' : 'Edit Fertilizer',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextField(
                controller: descriptionController,
                maxLines: null,
                minLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                if (fertilizer != null) {
                  final updatedFertilizer = fertilizer.copyWith(
                    id: fertilizer.id,
                    name: nameController.text,
                    description: descriptionController.text,
                  );
                  await fertilizerProvider.updateFertilizer(updatedFertilizer);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  return;
                }
                final newFertilizer = Fertilizer(
                  id: const Uuid().v4().toString(),
                  name: nameController.text,
                  description: descriptionController.text,
                );
                await fertilizerProvider.addFertilizer(newFertilizer);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}
