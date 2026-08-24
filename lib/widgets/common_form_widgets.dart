import 'package:flutter/material.dart';

Widget buildTextField({
  required String label,
  required String hint,
  required TextEditingController controller,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  bool required = true,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    validator: (value) {
      if (required && (value == null || value.trim().isEmpty)) {
        return '$label is required';
      }
      return null;
    },
  );
}

Widget twoFields({required Widget first, required Widget second}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: 12),
      Expanded(child: second),
    ],
  );
}

Widget gap() => const SizedBox(height: 14);

Widget sectionTitle(String title, IconData icon) {
  return Padding(
    padding: const EdgeInsets.only(top: 5, bottom: 14),
    child: Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
