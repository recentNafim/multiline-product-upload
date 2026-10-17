import 'package:flutter/material.dart';

/// Read-only, scrollable preview of the imported Excel rows.
class ExcelDataTablePreview extends StatelessWidget {
  final List<String> headers;
  final List<Map<String, dynamic>> rows;

  const ExcelDataTablePreview({
    super.key,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final visibleHeaders = headers.where((h) => !{
      'PRINT ITEM', 'QR CODE', 'TRACK MARK', 'FACTORY',
      'LOCATOR ID', 'UNIT PRICE',
    }.contains(h.trim().toUpperCase())).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Excel Preview (${rows.length} items)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('SL')),
                  ...visibleHeaders.map((h) => DataColumn(label: Text(h))),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(cells: [
                      DataCell(Text('${i + 1}')),
                      ...visibleHeaders.map((h) => DataCell(
                        SizedBox(
                          width: 145,
                          child: Text(
                            (rows[i][h] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
