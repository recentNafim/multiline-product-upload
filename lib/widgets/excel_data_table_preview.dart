import 'package:flutter/material.dart';

class ExcelDataTablePreview extends StatefulWidget {
  final List<String> headers;
  final List<Map<String, dynamic>> rows;

  const ExcelDataTablePreview({
    super.key,
    required this.headers,
    required this.rows,
  });

  @override
  State<ExcelDataTablePreview> createState() =>
      _ExcelDataTablePreviewState();
}

class _ExcelDataTablePreviewState extends State<ExcelDataTablePreview> {
  int _rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    if (widget.headers.isEmpty || widget.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableRows = <int>[10, 25, 50, 100]
        .where((value) => value <= widget.rows.length || value == 10)
        .toList();

    final rowsPerPage = availableRows.contains(_rowsPerPage)
        ? _rowsPerPage
        : availableRows.first;

    final source = _ExcelTableDataSource(
      headers: widget.headers,
      rows: widget.rows,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.dataset_outlined),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Excel Data Table',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${widget.rows.length} rows • ${widget.headers.length} columns',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Excel থেকে read করা data নিচের table-এ preview হচ্ছে। '
            'Horizontal scroll করে সব column দেখতে পারবেন।',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth =
                  (widget.headers.length * 160.0).clamp(900.0, 5200.0).toDouble();

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: PaginatedDataTable(
                    showCheckboxColumn: false,
                    headingRowHeight: 48,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 64,
                    horizontalMargin: 12,
                    columnSpacing: 18,
                    rowsPerPage: rowsPerPage,
                    availableRowsPerPage: availableRows,
                    onRowsPerPageChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _rowsPerPage = value;
                      });
                    },
                    columns: widget.headers
                        .map(
                          (header) => DataColumn(
                            label: SizedBox(
                              width: 140,
                              child: Text(
                                header,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    source: source,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExcelTableDataSource extends DataTableSource {
  final List<String> headers;
  final List<Map<String, dynamic>> rows;

  _ExcelTableDataSource({
    required this.headers,
    required this.rows,
  });

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= rows.length) {
      return null;
    }

    final row = rows[index];

    return DataRow.byIndex(
      index: index,
      cells: headers
          .map(
            (header) => DataCell(
              SizedBox(
                width: 140,
                child: Text(
                  _cellText(row[header]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  String _cellText(dynamic value) {
    if (value == null) return '';

    if (value is double && value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString().trim();
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

  @override
  int get selectedRowCount => 0;
}
