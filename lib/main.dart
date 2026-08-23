

import 'dart:convert';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Display Room Item Upload',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const ItemUploadScreen(),
      routes: {
        '/items': (context) => const DisplayRoomItemListPage(),
        '/delete': (context) => const DisplayRoomDeletePage(),
      },
    );
  }
}

class ItemUploadScreen extends StatefulWidget {
  const ItemUploadScreen({super.key});

  @override
  State<ItemUploadScreen> createState() =>
      _ItemUploadScreenState();
}

class _ItemUploadScreenState extends State<ItemUploadScreen> {
  static const String apiUrl = "https://e501.sihirbox.com:8071/ords/rpro/multiline-display-room/item-upload";
  // 'https://e502.sihirbox.com:8072/ords/rpro/'
  // 'multiline-display-room/item-upload';

  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isReadingExcel = false;

  String? selectedExcelName;

  /// Excel select করলে সব detail এখানে থাকবে।
  List<Map<String, dynamic>> excelDetails = [];

  // ============================================================
  // IMAGE STATE
  // ============================================================

  /// Manual item-এর জন্য সর্বোচ্চ 5টি image।
  final List<PlatformFile> selectedImages = [];

  /// Excel mode-এ IMAGE column-এর filename-এর সাথে match করার জন্য
  /// একসাথে অনেক image file select করা যাবে। Backend limit প্রতি item-এ 5।
  final List<PlatformFile> selectedExcelImages = [];

  bool isReadingImages = false;
  bool isReadingExcelImages = false;

  // ============================================================
  // MASTER CONTROLLERS
  // ============================================================

  final businessController = TextEditingController();
  final subCategoryController = TextEditingController();
  final organizationIdController = TextEditingController();
  final displayRoomNoController = TextEditingController();
  final displayRoomNameController = TextEditingController();
  final createdByController = TextEditingController();
  final statusController = TextEditingController();
  final assigneeController = TextEditingController();

  // ============================================================
  // DETAIL CONTROLLERS
  // ============================================================

  final sourceSlController = TextEditingController();
  final productCategoryController = TextEditingController();
  final printController = TextEditingController();
  final itemQrCodeController = TextEditingController();

  final fileUrlController = TextEditingController();
  final fileNameController = TextEditingController();
  final mimeTypeController = TextEditingController();

  final itemCodeController = TextEditingController();
  final descriptionController = TextEditingController();
  final uomController = TextEditingController();

  final quantityController = TextEditingController();
  final unitPriceController = TextEditingController();

  final subInventoryCodeController = TextEditingController();
  final locatorIdController = TextEditingController();

  final cbmController = TextEditingController();
  final fobController = TextEditingController();

  final materialSpecificationController =
  TextEditingController();

  final weightController = TextEditingController();

  // ============================================================
  // EXCEL HELPERS
  // ============================================================

  String normalizeHeader(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  dynamic getExcelValue(xls.Data? cell) {
    final value = cell?.value;

    if (value == null) {
      return null;
    }

    if (value is xls.TextCellValue) {
      return value.value;
    }

    if (value is xls.IntCellValue) {
      return value.value;
    }

    if (value is xls.DoubleCellValue) {
      return value.value;
    }

    if (value is xls.BoolCellValue) {
      return value.value;
    }

    if (value is xls.FormulaCellValue) {
      return value.formula;
    }

    if (value is xls.DateCellValue) {
      return value.asDateTimeLocal();
    }

    if (value is xls.DateTimeCellValue) {
      return value.asDateTimeLocal();
    }

    if (value is xls.TimeCellValue) {
      return value.asDuration();
    }

    return value.toString();
  }

  String asText(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is double &&
        value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString().trim();
  }

  int? asInt(dynamic value) {
    final text = asText(value)
        .replaceAll(',', '')
        .trim();

    if (text.isEmpty) {
      return null;
    }

    return int.tryParse(text) ??
        double.tryParse(text)?.toInt();
  }

  double? asDouble(dynamic value) {
    final text = asText(value)
        .replaceAll(',', '')
        .trim();

    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text);
  }

  String mimeTypeFromFileName(String fileName) {
    final name = fileName.toLowerCase();

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    if (name.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'application/octet-stream';
  }

  // ============================================================
  // IMAGE HELPERS
  // ============================================================

  List<String> _imageNamesFromExcelValue(dynamic value) {
    final text = asText(value);

    if (text.isEmpty) {
      return <String>[];
    }

    return text
        .split(RegExp(r'[,;|\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _platformFileToImageJson(PlatformFile file) {
    if (file.bytes == null) {
      throw Exception('${file.name} file-এর bytes পাওয়া যায়নি');
    }

    return <String, dynamic>{
      'picture_base64': base64Encode(file.bytes!),
      'file_name': file.name,
      'mime_type': mimeTypeFromFileName(file.name),
    };
  }

  List<Map<String, dynamic>> _manualImagesPayload() {
    return selectedImages
        .where((file) => file.bytes != null)
        .map(_platformFileToImageJson)
        .toList();
  }

  List<Map<String, dynamic>> _excelImagesPayloadForDetail(
      Map<String, dynamic> detail,
      ) {
    final rawNames = detail['_image_names'];

    final List<String> expectedNames = rawNames is List
        ? rawNames.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : _imageNamesFromExcelValue(detail['file_name']);

    if (expectedNames.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final lowerNames = expectedNames.map((e) => e.toLowerCase()).toSet();

    return selectedExcelImages
        .where(
          (file) =>
      file.bytes != null && lowerNames.contains(file.name.toLowerCase()),
    )
        .take(5)
        .map(_platformFileToImageJson)
        .toList();
  }

  Future<void> selectManualImages() async {
    if (selectedImages.length >= 5) {
      showError('একটি item-এর জন্য সর্বোচ্চ 5টি image select করা যাবে।');
      return;
    }

    try {
      setState(() {
        isReadingImages = true;
      });

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null) {
        return;
      }

      final remaining = 5 - selectedImages.length;
      final validFiles = result.files
          .where((file) => file.bytes != null)
          .take(remaining)
          .toList();

      if (validFiles.isEmpty) {
        showError('Selected image file read করা যাচ্ছে না।');
        return;
      }

      setState(() {
        selectedImages.addAll(validFiles);

        final first = selectedImages.first;
        fileNameController.text = first.name;
        fileUrlController.text = first.name;
        mimeTypeController.text = mimeTypeFromFileName(first.name);
      });

      if (result.files.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('সর্বোচ্চ 5টি image নেওয়া হয়েছে। অতিরিক্ত image বাদ দেওয়া হয়েছে।'),
          ),
        );
      }
    } catch (e) {
      showError('Image select failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isReadingImages = false;
        });
      }
    }
  }

  Future<void> selectExcelImages() async {
    try {
      setState(() {
        isReadingExcelImages = true;
      });

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null) {
        return;
      }

      final validFiles = result.files.where((file) => file.bytes != null).toList();

      if (validFiles.isEmpty) {
        showError('Selected image files read করা যাচ্ছে না।');
        return;
      }

      final Map<String, PlatformFile> merged = {
        for (final file in selectedExcelImages) file.name.toLowerCase(): file,
        for (final file in validFiles) file.name.toLowerCase(): file,
      };

      setState(() {
        selectedExcelImages
          ..clear()
          ..addAll(merged.values);
      });
    } catch (e) {
      showError('Excel image select failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isReadingExcelImages = false;
        });
      }
    }
  }

  void removeManualImage(int index) {
    setState(() {
      selectedImages.removeAt(index);

      if (selectedImages.isEmpty) {
        fileNameController.clear();
        fileUrlController.clear();
        mimeTypeController.clear();
      } else {
        final first = selectedImages.first;
        fileNameController.text = first.name;
        fileUrlController.text = first.name;
        mimeTypeController.text = mimeTypeFromFileName(first.name);
      }
    });
  }

  void clearExcelImages() {
    setState(() {
      selectedExcelImages.clear();
    });
  }

  // ============================================================
  // SELECT EXCEL
  // ============================================================

  Future<void> selectExcelFile() async {
    try {
      setState(() {
        isReadingExcel = true;
      });

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) {
        return;
      }

      final file = result.files.single;

      if (file.bytes == null) {
        throw Exception(
          'Excel file read করা যাচ্ছে না',
        );
      }

      final excel =
      xls.Excel.decodeBytes(file.bytes!);

      if (excel.tables.isEmpty) {
        throw Exception(
          'Excel file-এ কোনো sheet পাওয়া যায়নি',
        );
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception(
          'Excel sheet empty',
        );
      }

      // ========================================================
      // READ HEADERS
      // ========================================================

      final headerRow = sheet.rows.first;

      final List<String> headers = [];

      for (final cell in headerRow) {
        headers.add(
          normalizeHeader(
            asText(
              getExcelValue(cell),
            ),
          ),
        );
      }

      debugPrint('Excel Headers: $headers');

      // ========================================================
      // READ ROWS
      // ========================================================

      final List<Map<String, dynamic>> rows = [];

      for (
      int rowIndex = 1;
      rowIndex < sheet.rows.length;
      rowIndex++
      ) {
        final excelRow = sheet.rows[rowIndex];

        final Map<String, dynamic> row = {};

        for (
        int columnIndex = 0;
        columnIndex < headers.length;
        columnIndex++
        ) {
          final header = headers[columnIndex];

          if (header.isEmpty) {
            continue;
          }

          dynamic value;

          if (columnIndex < excelRow.length) {
            value = getExcelValue(
              excelRow[columnIndex],
            );
          }

          row[header] = value;
        }

        final itemCode =
        asText(row['ITEM CODE']);

        // Completely empty row skip
        if (itemCode.isEmpty) {
          continue;
        }

        rows.add(row);
      }

      if (rows.isEmpty) {
        throw Exception(
          'Excel file-এ valid item পাওয়া যায়নি',
        );
      }

      // ========================================================
      // FIRST ROW -> MASTER + MANUAL FIELD PREVIEW
      // ========================================================

      final firstRow = rows.first;

      setControllerIfAvailable(
        businessController,
        firstRow['BUSINESS'],
      );

      setControllerIfAvailable(
        subCategoryController,
        firstRow['SUB CATEGORY'],
      );

      setControllerIfAvailable(
        displayRoomNoController,
        firstRow['DISPLAY ROOM NO'],
      );

      setControllerIfAvailable(
        displayRoomNameController,
        firstRow['DISPLAY ROOM NAME'],
      );

      // Excel-এ Organization ID থাকলে fill করবে।
      setControllerIfAvailable(
        organizationIdController,
        firstRow['ORGANIZATION ID'],
      );

      // First detail row preview
      setControllerIfAvailable(
        sourceSlController,
        firstRow['SL'],
      );

      setControllerIfAvailable(
        productCategoryController,
        firstRow['PRODUCT CATEGORY'],
      );

      setControllerIfAvailable(
        printController,
        firstRow['PRINT'],
      );

      setControllerIfAvailable(
        itemQrCodeController,
        firstRow['ITEM QRCODE'],
      );

      setControllerIfAvailable(
        itemCodeController,
        firstRow['ITEM CODE'],
      );

      setControllerIfAvailable(
        descriptionController,
        firstRow['ITEM NAME'],
      );

      setControllerIfAvailable(
        uomController,
        firstRow['UOM'],
      );

      setControllerIfAvailable(
        quantityController,
        firstRow['QUANTITY'],
      );

      setControllerIfAvailable(
        unitPriceController,
        firstRow['UNIT PRICE'],
      );

      setControllerIfAvailable(
        subInventoryCodeController,
        firstRow['SUB INVENTORY CODE'],
      );

      setControllerIfAvailable(
        locatorIdController,
        firstRow['LOCATOR ID'],
      );

      setControllerIfAvailable(
        cbmController,
        firstRow['CBM'],
      );

      setControllerIfAvailable(
        fobController,
        firstRow['FOB'],
      );

      setControllerIfAvailable(
        materialSpecificationController,
        firstRow['MATERIAL SPECIFICATION'],
      );

      setControllerIfAvailable(
        weightController,
        firstRow['WEIGHT'],
      );

      final firstImageNames =
      _imageNamesFromExcelValue(firstRow['IMAGE']);

      if (firstImageNames.isNotEmpty) {
        final imageName = firstImageNames.first;
        fileUrlController.text = imageName;
        fileNameController.text = imageName;
        mimeTypeController.text = mimeTypeFromFileName(imageName);
      }

      // ========================================================
      // CREATE ALL EXCEL DETAILS
      // ========================================================

      final details = rows.map((row) {
        final imageNames =
        _imageNamesFromExcelValue(row['IMAGE']);

        if (imageNames.length > 5) {
          throw Exception(
            'Item ${asText(row['ITEM CODE'])}: প্রতি item-এ সর্বোচ্চ 5টি image allowed.',
          );
        }

        final firstImageName =
        imageNames.isNotEmpty ? imageNames.first : '';

        return <String, dynamic>{
          "source_sl":
          asInt(row['SL']),

          "product_category":
          asText(
            row['PRODUCT CATEGORY'],
          ),

          "print":
          asText(row['PRINT']),

          "item_qrcode":
          asText(
            row['ITEM QRCODE'],
          ),

          "file_url":
          firstImageName,

          "file_name":
          firstImageName,

          "mime_type":
          firstImageName.isEmpty
              ? ''
              : mimeTypeFromFileName(firstImageName),

          // Internal helper. API পাঠানোর আগে remove করা হবে।
          "_image_names":
          imageNames,

          "item_code":
          asText(
            row['ITEM CODE'],
          ),

          "description":
          asText(
            row['ITEM NAME'],
          ),

          "uom":
          asText(row['UOM']),

          "quantity":
          asDouble(
            row['QUANTITY'],
          ),

          "unit_price":
          asDouble(
            row['UNIT PRICE'],
          ),

          "sub_inventory_code":
          asText(
            row['SUB INVENTORY CODE'],
          ),

          "locator_id":
          asInt(
            row['LOCATOR ID'],
          ),

          "cbm":
          asText(row['CBM']),

          "fob":
          asDouble(row['FOB']),

          "material_specification":
          asText(
            row['MATERIAL SPECIFICATION'],
          ),

          "weight":
          asDouble(
            row['WEIGHT'],
          ),
        };
      }).toList();

      setState(() {
        selectedExcelName = file.name;
        excelDetails = details;
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '${details.length} Excel rows loaded',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isReadingExcel = false;
        });
      }
    }
  }

  void setControllerIfAvailable(
      TextEditingController controller,
      dynamic value,
      ) {
    final text = asText(value);

    if (text.isNotEmpty) {
      controller.text = text;
    }
  }

  // ============================================================
  // REMOVE EXCEL
  // ============================================================

  void removeExcel() {
    setState(() {
      selectedExcelName = null;
      excelDetails = [];
      selectedExcelImages.clear();
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Excel removed. Manual mode active.',
        ),
      ),
    );
  }

  // ============================================================
  // MANUAL DETAIL
  // ============================================================

  Map<String, dynamic> createManualDetail() {
    final PlatformFile? firstImage =
    selectedImages.isNotEmpty ? selectedImages.first : null;

    return {
      "source_sl": int.tryParse(
        sourceSlController.text.trim(),
      ),

      "product_category":
      productCategoryController.text.trim(),

      "print":
      printController.text.trim(),

      "item_qrcode":
      itemQrCodeController.text.trim(),

      "file_url":
      firstImage?.name ?? fileUrlController.text.trim(),

      "file_name":
      firstImage?.name ?? fileNameController.text.trim(),

      "mime_type":
      firstImage != null
          ? mimeTypeFromFileName(firstImage.name)
          : mimeTypeController.text.trim(),

      "images":
      _manualImagesPayload(),

      "item_code":
      itemCodeController.text.trim(),

      "description":
      descriptionController.text.trim(),

      "uom":
      uomController.text.trim(),

      "quantity": double.tryParse(
        quantityController.text.trim(),
      ),

      "unit_price": double.tryParse(
        unitPriceController.text.trim(),
      ),

      "sub_inventory_code":
      subInventoryCodeController.text.trim(),

      "locator_id": int.tryParse(
        locatorIdController.text.trim(),
      ),

      "cbm":
      cbmController.text.trim(),

      "fob": double.tryParse(
        fobController.text.trim(),
      ),

      "material_specification":
      materialSpecificationController
          .text
          .trim(),

      "weight": double.tryParse(
        weightController.text.trim(),
      ),
    };
  }

  // ============================================================
  // API SUBMIT
  // ============================================================

  Future<void> uploadItem() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final organizationId = int.tryParse(
      organizationIdController.text.trim(),
    );

    final createdBy = int.tryParse(
      createdByController.text.trim(),
    );

    final assignee = int.tryParse(
      assigneeController.text.trim(),
    );

    if (organizationId == null) {
      showError(
        'Valid Organization ID দিন',
      );
      return;
    }

    if (createdBy == null) {
      showError(
        'Valid Created By দিন',
      );
      return;
    }

    if (assignee == null) {
      showError(
        'Valid Assignee দিন',
      );
      return;
    }

    // ==========================================================
    // IMPORTANT
    //
    // Excel selected থাকলে -> Excel details[]
    // Excel না থাকলে -> Manual single detail
    // ==========================================================

    final List<Map<String, dynamic>> details;

    if (excelDetails.isNotEmpty) {
      details = excelDetails.map((original) {
        final detail = Map<String, dynamic>.from(original);
        detail['images'] = _excelImagesPayloadForDetail(detail);
        detail.remove('_image_names');
        return detail;
      }).toList();
    } else {
      details = [
        createManualDetail(),
      ];
    }

    final Map<String, dynamic> body = {
      "business":
      businessController.text.trim(),

      "sub_category":
      subCategoryController.text.trim(),

      "organization_id":
      organizationId,

      "display_room_no":
      displayRoomNoController.text.trim(),

      "display_room_name":
      displayRoomNameController.text.trim(),

      "created_by":
      createdBy,

      "status":
      statusController.text.trim(),

      "assignee":
      assignee,

      "details":
      details,
    };

    final int totalImageCount = details.fold<int>(
      0,
          (sum, detail) =>
      sum + ((detail['images'] is List) ? (detail['images'] as List).length : 0),
    );

    debugPrint('==========================================');
    debugPrint('POST DISPLAY ROOM ITEM UPLOAD');
    debugPrint('URL => $apiUrl');
    debugPrint('DETAIL COUNT => ${details.length}');
    debugPrint('IMAGE COUNT => $totalImageCount');
    debugPrint('==========================================');

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type':
          'application/json',
          'Accept':
          'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(
          seconds: 120,
        ),
      );

      debugPrint(
        'HTTP: ${response.statusCode}',
      );

      debugPrint(
        'Response: ${response.body}',
      );

      dynamic json;

      try {
        json = jsonDecode(
          response.body,
        );
      } catch (_) {
        json = null;
      }

      final apiStatus =
      json is Map
          ? json['status_code']
          : null;

      final message =
      json is Map
          ? json['message']
          ?.toString() ??
          'Request completed'
          : response.body;

      final success =
          response.statusCode >= 200 &&
              response.statusCode < 300 &&
              (
                  apiStatus == null ||
                      apiStatus == 200 ||
                      apiStatus.toString() ==
                          '200'
              );

      if (!mounted) {
        return;
      }

      if (success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              excelDetails.isNotEmpty
                  ? '$message\n${excelDetails.length} items uploaded.'
                  : message,
            ),
          ),
        );
      } else {
        showError(message);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      showError(
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType =
        TextInputType.text,
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
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(10),
        ),
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (required &&
            (value == null ||
                value.trim().isEmpty)) {
          return '$label is required';
        }

        return null;
      },
    );
  }

  // ============================================================
  // TWO FIELDS
  // ============================================================

  Widget twoFields({
    required Widget first,
    required Widget second,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(child: first),

        const SizedBox(width: 12),

        Expanded(child: second),
      ],
    );
  }

  Widget gap() =>
      const SizedBox(height: 14);

  Widget sectionTitle(
      String title,
      IconData icon,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        top: 5,
        bottom: 14,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXCEL OPTION UI
  // ============================================================

  Widget buildExcelOption() {
    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.table_view_outlined,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Excel Upload (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              if (selectedExcelName != null)
                IconButton(
                  onPressed:
                  isLoading
                      ? null
                      : removeExcel,
                  icon: const Icon(
                    Icons.close,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            'Manual entry অথবা Excel — '
                'দুইভাবেই upload করতে পারবেন।',
            style: TextStyle(
              fontSize: 13,
              color:
              Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed:
            isReadingExcel ||
                isLoading
                ? null
                : selectExcelFile,
            icon: isReadingExcel
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.upload_file,
            ),
            label: Text(
              isReadingExcel
                  ? 'Reading Excel...'
                  : 'Select Excel File',
            ),
          ),

          if (selectedExcelName != null) ...[
            const SizedBox(height: 10),

            Container(
              padding:
              const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                Colors.green.shade50,
                borderRadius:
                BorderRadius.circular(
                  8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          selectedExcelName!,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),

                        Text(
                          '${excelDetails.length} item(s) loaded',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: isReadingExcelImages || isLoading
                  ? null
                  : selectExcelImages,
              icon: isReadingExcelImages
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                isReadingExcelImages
                    ? 'Reading Images...'
                    : 'Select Excel Image Files',
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Excel-এর IMAGE column-এর filename-এর সাথে selected image file match হবে. '
                  'একটি cell-এ multiple image হলে comma/semicolon দিয়ে filename লিখতে পারবেন.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            if (selectedExcelImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...selectedExcelImages.map(
                        (file) => Chip(
                      avatar: const Icon(Icons.image_outlined, size: 18),
                      label: Text(file.name),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear Images'),
                    onPressed: isLoading ? null : clearExcelImages,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ============================================================
  // MANUAL IMAGE PICKER UI
  // ============================================================

  Widget buildManualImagePicker() {
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
              const Icon(Icons.photo_library_outlined),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Product Images',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${selectedImages.length}/5',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'JPG, JPEG, PNG, WEBP বা GIF — একটি item-এ সর্বোচ্চ 5টি image.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isReadingImages || isLoading || selectedImages.length >= 5
                ? null
                : selectManualImages,
            icon: isReadingImages
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              isReadingImages
                  ? 'Reading Images...'
                  : selectedImages.isEmpty
                  ? 'Select Images'
                  : 'Add More Images',
            ),
          ),
          if (selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                selectedImages.length,
                    (index) {
                  final file = selectedImages[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 120,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: file.bytes != null
                                  ? Image.memory(
                                file.bytes!,
                                width: 100,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                                  : Container(
                                width: 100,
                                height: 80,
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Material(
                          color: Colors.red,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: isLoading ? null : () => removeManualImage(index),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Display Room Item Upload',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'View Items',
            onPressed: () {
              Navigator.pushNamed(context, '/items');
            },
            icon: const Icon(Icons.list_alt_outlined),
          ),
          IconButton(
            tooltip: 'Delete Items',
            onPressed: () {
              Navigator.pushNamed(context, '/delete');
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                // ==================================================
                // EXCEL = OPTIONAL ONLY
                // ==================================================

                buildExcelOption(),

                const SizedBox(height: 25),

                // ==================================================
                // MASTER INFORMATION
                // ==================================================

                sectionTitle(
                  'Master Information',
                  Icons.meeting_room_outlined,
                ),

                twoFields(
                  first: buildTextField(
                    label: 'Business',
                    hint: 'e.g. Footwear',
                    controller:
                    businessController,
                  ),
                  second: buildTextField(
                    label: 'Sub Category',
                    hint: 'e.g. Export',
                    controller:
                    subCategoryController,
                  ),
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label:
                    'Organization ID',
                    hint: 'e.g. 3941',
                    controller:
                    organizationIdController,
                    keyboardType:
                    TextInputType.number,
                  ),
                  second: buildTextField(
                    label: 'Created By',
                    hint: 'e.g. 506618',
                    controller:
                    createdByController,
                    keyboardType:
                    TextInputType.number,
                  ),
                ),

                gap(),

                buildTextField(
                  label: 'Display Room No',
                  hint:
                  'e.g. MLIL-R10-Ftwr-Disply',
                  controller:
                  displayRoomNoController,
                ),

                gap(),

                buildTextField(
                  label:
                  'Display Room Name',
                  hint:
                  'e.g. MLIL-R10-Ftwr-Display Room',
                  controller:
                  displayRoomNameController,
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'Status',
                    hint: 'e.g. ACTIVE',
                    controller:
                    statusController,
                  ),
                  second: buildTextField(
                    label: 'Assignee',
                    hint: 'e.g. 506618',
                    controller:
                    assigneeController,
                    keyboardType:
                    TextInputType.number,
                  ),
                ),

                const SizedBox(height: 25),
                const Divider(),
                const SizedBox(height: 8),

                // ==================================================
                // ITEM DETAILS
                // ==================================================

                sectionTitle(
                  'Item Details',
                  Icons.inventory_2_outlined,
                ),

                if (excelDetails.isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: 14,
                    ),
                    child: Container(
                      padding:
                      const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                      BoxDecoration(
                        color: Colors
                            .blue.shade50,
                        borderRadius:
                        BorderRadius
                            .circular(8),
                      ),
                      child: Text(
                        'Excel mode: নিচে first item preview '
                            'দেখানো হচ্ছে। Submit করলে '
                            '${excelDetails.length}টি item details[]-এ যাবে।',
                      ),
                    ),
                  ),

                twoFields(
                  first: buildTextField(
                    label: 'Source SL',
                    hint: 'e.g. 401',
                    controller:
                    sourceSlController,
                    keyboardType:
                    TextInputType.number,
                  ),
                  second: buildTextField(
                    label:
                    'Product Category',
                    hint: 'e.g. Cemented',
                    controller:
                    productCategoryController,
                  ),
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'Print',
                    hint:
                    'e.g. 0100247925',
                    controller:
                    printController,
                  ),
                  second: buildTextField(
                    label:
                    'Item QR Code',
                    hint:
                    'e.g. 0100247925',
                    controller:
                    itemQrCodeController,
                  ),
                ),

                gap(),

                buildTextField(
                  label: 'Item Code',
                  hint:
                  'e.g. 0100247925',
                  controller:
                  itemCodeController,
                ),

                gap(),

                buildTextField(
                  label: 'Description',
                  hint:
                  'e.g. LIDL SEMI FINISHED UPPER WHITE',
                  controller:
                  descriptionController,
                  maxLines: 2,
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'UOM',
                    hint: 'e.g. Pair',
                    controller:
                    uomController,
                  ),
                  second: buildTextField(
                    label: 'Quantity',
                    hint: 'e.g. 1236',
                    controller:
                    quantityController,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'Unit Price',
                    hint: 'e.g. 1.26',
                    controller:
                    unitPriceController,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  second: buildTextField(
                    label: 'FOB',
                    hint: 'e.g. 4.35',
                    controller:
                    fobController,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),

                gap(),

                buildTextField(
                  label:
                  'Sub Inventory Code',
                  hint: 'e.g. PN1.RM',
                  controller:
                  subInventoryCodeController,
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'Locator ID',
                    hint: 'e.g. 19680',
                    controller:
                    locatorIdController,
                    keyboardType:
                    TextInputType.number,
                  ),
                  second: buildTextField(
                    label: 'CBM',
                    hint: 'e.g. 54',
                    controller:
                    cbmController,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),

                gap(),

                buildTextField(
                  label:
                  'Material Specification',
                  hint:
                  'e.g. Mesh+3mm Foam+42gtc lamination',
                  controller:
                  materialSpecificationController,
                  maxLines: 2,
                ),

                gap(),

                if (excelDetails.isEmpty) ...[
                  buildManualImagePicker(),
                  gap(),
                ],

                twoFields(
                  first: buildTextField(
                    label: 'Weight',
                    hint: 'e.g. 0.2',
                    controller:
                    weightController,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  second: buildTextField(
                    label: 'MIME Type',
                    hint: 'Auto from selected image',
                    controller:
                    mimeTypeController,
                    required: false,
                  ),
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'File Name',
                    hint:
                    'Auto from selected image',
                    controller:
                    fileNameController,
                    required: false,
                  ),
                  second: buildTextField(
                    label: 'File URL',
                    hint:
                    'Auto from selected image',
                    controller:
                    fileUrlController,
                    required: false,
                  ),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // SUBMIT
                // ==================================================

                SizedBox(
                  height: 55,
                  child: FilledButton.icon(
                    onPressed:
                    isLoading
                        ? null
                        : uploadItem,
                    icon: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.cloud_upload,
                    ),
                    label: Text(
                      isLoading
                          ? 'Uploading...'
                          : excelDetails.isNotEmpty
                          ? 'Upload ${excelDetails.length} Excel Items'
                          : 'Submit Item',
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    businessController.dispose();
    subCategoryController.dispose();
    organizationIdController.dispose();
    displayRoomNoController.dispose();
    displayRoomNameController.dispose();
    createdByController.dispose();
    statusController.dispose();
    assigneeController.dispose();

    sourceSlController.dispose();
    productCategoryController.dispose();
    printController.dispose();
    itemQrCodeController.dispose();
    fileUrlController.dispose();
    fileNameController.dispose();
    mimeTypeController.dispose();
    itemCodeController.dispose();
    descriptionController.dispose();
    uomController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    subInventoryCodeController.dispose();
    locatorIdController.dispose();
    cbmController.dispose();
    fobController.dispose();
    materialSpecificationController.dispose();
    weightController.dispose();

    super.dispose();
  }
}

// ============================================================================
// DISPLAY ROOM ITEM LIST + EDIT PAGE
// ============================================================================

class DisplayRoomItemListPage extends StatefulWidget {
  const DisplayRoomItemListPage({super.key});

  @override
  State<DisplayRoomItemListPage> createState() =>
      _DisplayRoomItemListPageState();
}

class _DisplayRoomItemListPageState extends State<DisplayRoomItemListPage> {
  // GET এবং PUT একই resource path ধরে রাখা হয়েছে।
  // GET handler অন্য URL হলে শুধু listApiUrl change করবে।
  static const String listApiUrl =
      'https://e502.sihirbox.com:8072/ords/rpro/'
      'multiline-display-room/item-upload';

  static const String updateApiUrl =
      'https://e502.sihirbox.com:8072/ords/rpro/'
      'multiline-display-room/item-upload';

  final searchController = TextEditingController();

  bool isLoading = false;
  List<DisplayRoomItem> items = [];
  List<DisplayRoomItem> filteredItems = [];

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterItems);
    getItems();
  }

  Future<void> getItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(listApiUrl),
        headers: const {
          'Accept': 'application/json',
        },
      );

      debugPrint('GET STATUS: ${response.statusCode}');
      debugPrint('GET RESPONSE: ${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final data = _extractList(decoded);

      final loadedItems = data
          .whereType<Map>()
          .map(
            (e) => DisplayRoomItem.fromJson(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        items = loadedItems;
        filteredItems = loadedItems;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Item load failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map) {
      const possibleKeys = [
        'items',
        'ITEMS',
        'data',
        'DATA',
        'details',
        'DETAILS',
        'item_list',
        'ITEM_LIST',
      ];

      for (final key in possibleKeys) {
        if (decoded[key] is List) {
          return List<dynamic>.from(decoded[key]);
        }
      }
    }

    return [];
  }

  void _filterItems() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredItems = items;
      });
      return;
    }

    setState(() {
      filteredItems = items.where((item) {
        return item.itemCode.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.productCategory.toLowerCase().contains(query) ||
            item.subInventoryCode.toLowerCase().contains(query) ||
            item.displayRoomName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> openEditSheet(DisplayRoomItem item) async {
    if (item.sl == null) {
      _showMessage(
        'এই item-এর DETAILS.SL পাওয়া যায়নি। GET API-তে SL return করতে হবে।',
        isError: true,
      );
      return;
    }

    final updatedByController = TextEditingController(
      text: (item.updatedBy ?? item.createdBy)?.toString() ?? '',
    );
    final sourceSlController = TextEditingController(text: item.sourceSl);
    final productCategoryController =
    TextEditingController(text: item.productCategory);
    final printController = TextEditingController(text: item.printValue);
    final qrController = TextEditingController(text: item.itemQrCode);
    final itemCodeController = TextEditingController(text: item.itemCode);
    final descriptionController = TextEditingController(text: item.description);
    final uomController = TextEditingController(text: item.uom);
    final quantityController =
    TextEditingController(text: item.quantity?.toString() ?? '');
    final unitPriceController =
    TextEditingController(text: item.unitPrice?.toString() ?? '');
    final subInventoryController =
    TextEditingController(text: item.subInventoryCode);
    final locatorController =
    TextEditingController(text: item.locatorId?.toString() ?? '');
    final cbmController = TextEditingController(text: item.cbm);
    final fobController =
    TextEditingController(text: item.fob?.toString() ?? '');
    final weightController =
    TextEditingController(text: item.weight?.toString() ?? '');
    final specificationController =
    TextEditingController(text: item.materialSpecification);
    final fileUrlController = TextEditingController(text: item.fileUrl);
    final fileNameController = TextEditingController(text: item.fileName);
    final mimeController = TextEditingController(text: item.mimeType);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 960),
      builder: (sheetContext) {
        bool updating = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .88,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit Item',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item.itemCode,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: updating
                              ? null
                              : () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _editField(
                              label: 'Updated By',
                              controller: updatedByController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Source SL',
                                controller: sourceSlController,
                              ),
                              _editField(
                                label: 'Product Category',
                                controller: productCategoryController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Print',
                                controller: printController,
                              ),
                              _editField(
                                label: 'Item QR Code',
                                controller: qrController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Item Code',
                              controller: itemCodeController,
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Description',
                              controller: descriptionController,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'UOM',
                                controller: uomController,
                              ),
                              _editField(
                                label: 'Quantity',
                                controller: quantityController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Unit Price',
                                controller: unitPriceController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                              _editField(
                                label: 'FOB',
                                controller: fobController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Sub Inventory Code',
                              controller: subInventoryController,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Locator ID',
                                controller: locatorController,
                                keyboardType: TextInputType.number,
                              ),
                              _editField(
                                label: 'CBM',
                                controller: cbmController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Material Specification',
                              controller: specificationController,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Weight',
                                controller: weightController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                              _editField(
                                label: 'MIME Type',
                                controller: mimeController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'File Name',
                                controller: fileNameController,
                              ),
                              _editField(
                                label: 'File URL',
                                controller: fileUrlController,
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: updating
                            ? null
                            : () async {
                          final updatedBy = int.tryParse(
                            updatedByController.text.trim(),
                          );

                          if (updatedBy == null) {
                            _showMessage(
                              'Valid Updated By দিন',
                              isError: true,
                            );
                            return;
                          }

                          setSheetState(() {
                            updating = true;
                          });

                          final success = await updateItem(
                            item: item,
                            updatedBy: updatedBy,
                            sourceSl: sourceSlController.text,
                            productCategory:
                            productCategoryController.text,
                            printValue: printController.text,
                            qrCode: qrController.text,
                            itemCode: itemCodeController.text,
                            description: descriptionController.text,
                            uom: uomController.text,
                            quantity: quantityController.text,
                            unitPrice: unitPriceController.text,
                            subInventory: subInventoryController.text,
                            locatorId: locatorController.text,
                            cbm: cbmController.text,
                            fob: fobController.text,
                            weight: weightController.text,
                            specification:
                            specificationController.text,
                            fileUrl: fileUrlController.text,
                            fileName: fileNameController.text,
                            mimeType: mimeController.text,
                          );

                          if (!sheetContext.mounted) return;

                          if (success) {
                            Navigator.pop(sheetContext);
                            await getItems();
                          } else {
                            setSheetState(() {
                              updating = false;
                            });
                          }
                        },
                        icon: updating
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          updating ? 'Updating...' : 'Update Item',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    updatedByController.dispose();
    sourceSlController.dispose();
    productCategoryController.dispose();
    printController.dispose();
    qrController.dispose();
    itemCodeController.dispose();
    descriptionController.dispose();
    uomController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    subInventoryController.dispose();
    locatorController.dispose();
    cbmController.dispose();
    fobController.dispose();
    weightController.dispose();
    specificationController.dispose();
    fileUrlController.dispose();
    fileNameController.dispose();
    mimeController.dispose();
  }

  Future<bool> updateItem({
    required DisplayRoomItem item,
    required int updatedBy,
    required String sourceSl,
    required String productCategory,
    required String printValue,
    required String qrCode,
    required String itemCode,
    required String description,
    required String uom,
    required String quantity,
    required String unitPrice,
    required String subInventory,
    required String locatorId,
    required String cbm,
    required String fob,
    required String weight,
    required String specification,
    required String fileUrl,
    required String fileName,
    required String mimeType,
  }) async {
    if (item.organizationId == null || item.displayRoomNo.trim().isEmpty) {
      _showMessage(
        'GET API-তে ORGANIZATION_ID এবং DISPLAY_ROOM_NO return করতে হবে।',
        isError: true,
      );
      return false;
    }

    final body = {
      'business': item.business,
      'sub_category': item.subCategory,
      'organization_id': item.organizationId,
      'display_room_no': item.displayRoomNo,
      'display_room_name': item.displayRoomName,
      'updated_by': updatedBy,
      'status': item.status,
      'assignee': item.assignee,
      'details': [
        {
          'sl': item.sl,
          'source_sl': sourceSl.trim(),
          'product_category': productCategory.trim(),
          'print': printValue.trim(),
          'item_qrcode': qrCode.trim(),
          'file_url': fileUrl.trim(),
          'file_name': fileName.trim(),
          'mime_type': mimeType.trim(),
          'item_code': itemCode.trim(),
          'description': description.trim(),
          'uom': uom.trim(),
          'quantity': double.tryParse(quantity.trim()),
          'unit_price': double.tryParse(unitPrice.trim()),
          'sub_inventory_code': subInventory.trim(),
          'locator_id': int.tryParse(locatorId.trim()),
          'cbm': cbm.trim(),
          'fob': double.tryParse(fob.trim()),
          'material_specification': specification.trim(),
          'weight': double.tryParse(weight.trim()),
        }
      ],
    };

    try {
      debugPrint(
        const JsonEncoder.withIndent('  ').convert(body),
      );

      final response = await http
          .put(
        Uri.parse(updateApiUrl),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 60));

      debugPrint('PUT STATUS: ${response.statusCode}');
      debugPrint('PUT RESPONSE: ${response.body}');

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final apiStatus = decoded is Map ? decoded['status_code'] : null;
      final message = decoded is Map
          ? decoded['message']?.toString() ?? ''
          : response.body;

      final success = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (apiStatus == null ||
              apiStatus == 200 ||
              apiStatus.toString() == '200');

      if (mounted) {
        _showMessage(
          message.isEmpty
              ? (success ? 'Updated successfully.' : 'Update failed.')
              : message,
          isError: !success,
        );
      }

      return success;
    } catch (e) {
      if (mounted) {
        _showMessage('Update failed: $e', isError: true);
      }
      return false;
    }
  }

  Widget _editField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _twoEditFields(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 550) {
          return Column(
            children: [
              first,
              const SizedBox(height: 14),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red : Colors.green,
        content: Text(message),
      ),
    );
  }

  Widget _buildItemCard(DisplayRoomItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEditSheet(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemCode.isEmpty ? 'No Item Code' : item.itemCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _smallChip(item.productCategory),
                        _smallChip(item.uom),
                        _smallChip('Qty: ${item.quantity ?? 0}'),
                        _smallChip(item.subInventoryCode),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.edit_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallChip(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Room Items'),
        actions: [
          IconButton(
            tooltip: 'Delete Items',
            onPressed: () {
              Navigator.pushNamed(context, '/delete');
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : getItems,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search item code, name, category...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredItems.length} item(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredItems.isEmpty
                    ? const Center(child: Text('No items found.'))
                    : RefreshIndicator(
                  onRefresh: getItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(filteredItems[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_filterItems);
    searchController.dispose();
    super.dispose();
  }
}

// ============================================================================
// DISPLAY ROOM DELETE PAGE
// ============================================================================

class DisplayRoomDeletePage extends StatefulWidget {
  const DisplayRoomDeletePage({super.key});

  @override
  State<DisplayRoomDeletePage> createState() =>
      _DisplayRoomDeletePageState();
}

class _DisplayRoomDeletePageState extends State<DisplayRoomDeletePage> {
  // --------------------------------------------------------------------------
  // GET + DELETE use the E501 resource requested for this system.
  // --------------------------------------------------------------------------
  static const String apiUrl =
      'https://e501.sihirbox.com:8071/ords/rpro/'
      'multiline-display-room/item-upload';

  static const String imageBaseUrl =
      'https://e501.sihirbox.com:8071/ords/rpro/'
      'image_service/get/';

  final TextEditingController searchController =
  TextEditingController();

  bool isLoading = false;
  String? deletingKey;

  List<_DeleteProductRow> products = [];
  List<_DeleteProductRow> filteredProducts = [];

  List<_DeleteMasterRow> masters = [];
  List<_DeleteMasterRow> filteredMasters = [];

  @override
  void initState() {
    super.initState();
    searchController.addListener(_applyFilter);
    _loadDeleteData();
  }

  // ==========================================================================
  // LOAD GET DATA
  // ==========================================================================

  Future<void> _loadDeleteData() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .get(
        Uri.parse(apiUrl),
        headers: const {
          'Accept': 'application/json',
        },
      )
          .timeout(
        const Duration(seconds: 60),
      );

      debugPrint('==========================================');
      debugPrint('DELETE PAGE GET');
      debugPrint('URL => $apiUrl');
      debugPrint('STATUS => ${response.statusCode}');
      debugPrint('==========================================');

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final dynamic decoded =
      jsonDecode(response.body);

      final parsed =
      _parseDeleteResponse(decoded);

      if (!mounted) {
        return;
      }

      setState(() {
        products = parsed.products;
        masters = parsed.masters;
      });

      _applyFilter();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Delete page data load failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ==========================================================================
  // PARSE API RESPONSE
  //
  // Supports the current nested response:
  //
  // data: [
  //   {
  //     sl: MASTER_SL,
  //     ...
  //     details: [
  //       {
  //         sl: DETAIL_SL,
  //         ...
  //         images: [...]
  //       }
  //     ]
  //   }
  // ]
  //
  // Also supports a flat list for backward compatibility.
  // ==========================================================================

  _DeleteParsedData _parseDeleteResponse(
      dynamic decoded,
      ) {
    final List<_DeleteProductRow> productRows = [];
    final List<_DeleteMasterRow> masterRows = [];

    List<dynamic> rootList = [];

    if (decoded is List) {
      rootList = decoded;
    } else if (decoded is Map) {
      const possibleKeys = [
        'data',
        'DATA',
        'items',
        'ITEMS',
        'item_list',
        'ITEM_LIST',
      ];

      for (final key in possibleKeys) {
        if (decoded[key] is List) {
          rootList =
          List<dynamic>.from(decoded[key]);
          break;
        }
      }
    }

    for (final dynamic raw in rootList) {
      if (raw is! Map) {
        continue;
      }

      final Map<String, dynamic> master =
      Map<String, dynamic>.from(raw);

      final dynamic detailsRaw =
          master['details'] ??
              master['DETAILS'];

      // ----------------------------------------------------------------------
      // NESTED MASTER + DETAILS RESPONSE
      // ----------------------------------------------------------------------
      if (detailsRaw is List) {
        final int? masterSl = _asInt(
          master['sl'] ??
              master['SL'] ??
              master['master_sl'] ??
              master['MASTER_SL'],
        );

        final String business =
        _asText(
          master['business'] ??
              master['BUSINESS'],
        );

        final String subCategory =
        _asText(
          master['sub_category'] ??
              master['SUB_CATEGORY'],
        );

        final String displayRoomNo =
        _asText(
          master['display_room_no'] ??
              master['DISPLAY_ROOM_NO'],
        );

        final String displayRoomName =
        _asText(
          master['display_room_name'] ??
              master['DISPLAY_ROOM_NAME'],
        );

        final String organizationCode =
        _asText(
          master['organization_code'] ??
              master['ORGANIZATION_CODE'],
        );

        final int? organizationId =
        _asInt(
          master['organization_id'] ??
              master['ORGANIZATION_ID'],
        );

        final String status =
        _asText(
          master['status'] ??
              master['STATUS'],
        );

        masterRows.add(
          _DeleteMasterRow(
            masterSl: masterSl,
            business: business,
            subCategory: subCategory,
            displayRoomNo: displayRoomNo,
            displayRoomName: displayRoomName,
            organizationCode:
            organizationCode,
            organizationId:
            organizationId,
            status: status,
            detailsCount:
            detailsRaw.length,
          ),
        );

        for (final dynamic detailRaw
        in detailsRaw) {
          if (detailRaw is! Map) {
            continue;
          }

          final Map<String, dynamic> detail =
          Map<String, dynamic>.from(
            detailRaw,
          );

          productRows.add(
            _DeleteProductRow(
              detailSl: _asInt(
                detail['sl'] ??
                    detail['SL'] ??
                    detail['detail_sl'] ??
                    detail['DETAIL_SL'],
              ),
              masterSl: _asInt(
                detail['m_sl'] ??
                    detail['M_SL'] ??
                    detail['master_sl'] ??
                    detail['MASTER_SL'],
              ) ??
                  masterSl,
              itemCode: _asText(
                detail['item_code'] ??
                    detail['ITEM_CODE'],
              ),
              description: _asText(
                detail['description'] ??
                    detail['DESCRIPTION'],
              ),
              productCategory: _asText(
                detail['product_category'] ??
                    detail['PRODUCT_CATEGORY'],
              ),
              business: _asText(
                detail['business'] ??
                    detail['BUSINESS'],
              ).isNotEmpty
                  ? _asText(
                detail['business'] ??
                    detail['BUSINESS'],
              )
                  : business,
              subCategory: _asText(
                detail['sub_category'] ??
                    detail['SUB_CATEGORY'],
              ).isNotEmpty
                  ? _asText(
                detail['sub_category'] ??
                    detail['SUB_CATEGORY'],
              )
                  : subCategory,
              displayRoomNo: _asText(
                detail['display_room_no'] ??
                    detail['DISPLAY_ROOM_NO'],
              ).isNotEmpty
                  ? _asText(
                detail['display_room_no'] ??
                    detail['DISPLAY_ROOM_NO'],
              )
                  : displayRoomNo,
              displayRoomName: _asText(
                detail['display_room_name'] ??
                    detail['DISPLAY_ROOM_NAME'],
              ).isNotEmpty
                  ? _asText(
                detail['display_room_name'] ??
                    detail['DISPLAY_ROOM_NAME'],
              )
                  : displayRoomName,
              imageUrl:
              _firstImageUrl(detail),
            ),
          );
        }

        continue;
      }

      // ----------------------------------------------------------------------
      // FLAT DETAIL RESPONSE FALLBACK
      // ----------------------------------------------------------------------
      final int? detailSl = _asInt(
        master['sl'] ??
            master['SL'] ??
            master['detail_sl'] ??
            master['DETAIL_SL'],
      );

      final int? masterSl = _asInt(
        master['m_sl'] ??
            master['M_SL'] ??
            master['master_sl'] ??
            master['MASTER_SL'],
      );

      productRows.add(
        _DeleteProductRow(
          detailSl: detailSl,
          masterSl: masterSl,
          itemCode: _asText(
            master['item_code'] ??
                master['ITEM_CODE'],
          ),
          description: _asText(
            master['description'] ??
                master['DESCRIPTION'],
          ),
          productCategory: _asText(
            master['product_category'] ??
                master['PRODUCT_CATEGORY'],
          ),
          business: _asText(
            master['business'] ??
                master['BUSINESS'],
          ),
          subCategory: _asText(
            master['sub_category'] ??
                master['SUB_CATEGORY'],
          ),
          displayRoomNo: _asText(
            master['display_room_no'] ??
                master['DISPLAY_ROOM_NO'],
          ),
          displayRoomName: _asText(
            master['display_room_name'] ??
                master['DISPLAY_ROOM_NAME'],
          ),
          imageUrl:
          _firstImageUrl(master),
        ),
      );
    }

    // ------------------------------------------------------------------------
    // If flat response had no master list, derive masters from product rows.
    // ------------------------------------------------------------------------
    if (masterRows.isEmpty) {
      final Map<int, List<_DeleteProductRow>>
      grouped = {};

      for (final item in productRows) {
        if (item.masterSl == null) {
          continue;
        }

        grouped
            .putIfAbsent(
          item.masterSl!,
              () => [],
        )
            .add(item);
      }

      for (final entry in grouped.entries) {
        final first =
            entry.value.first;

        masterRows.add(
          _DeleteMasterRow(
            masterSl: entry.key,
            business: first.business,
            subCategory:
            first.subCategory,
            displayRoomNo:
            first.displayRoomNo,
            displayRoomName:
            first.displayRoomName,
            organizationCode: '',
            organizationId: null,
            status: '',
            detailsCount:
            entry.value.length,
          ),
        );
      }
    }

    return _DeleteParsedData(
      products: productRows,
      masters: masterRows,
    );
  }

  // ==========================================================================
  // IMAGE URL
  // ==========================================================================

  String _firstImageUrl(
      Map<String, dynamic> data,
      ) {
    String normalize(dynamic value) {
      if (value == null) {
        return '';
      }

      String url =
      value.toString().trim();

      if (url.isEmpty ||
          url.toLowerCase() == 'null') {
        return '';
      }

      if (url.startsWith('http://') ||
          url.startsWith('https://')) {
        return url;
      }

      while (url.startsWith('/')) {
        url = url.substring(1);
      }

      if (url.isEmpty) {
        return '';
      }

      return '$imageBaseUrl'
          '${Uri.encodeComponent(url)}';
    }

    String url = normalize(
      data['image_url'] ??
          data['IMAGE_URL'],
    );

    if (url.isNotEmpty) {
      return url;
    }

    url = normalize(
      data['file_url'] ??
          data['FILE_URL'],
    );

    if (url.isNotEmpty) {
      return url;
    }

    final dynamic images =
        data['images'] ??
            data['IMAGES'];

    if (images is List) {
      for (final dynamic image
      in images) {
        if (image is! Map) {
          continue;
        }

        url = normalize(
          image['image_url'] ??
              image['IMAGE_URL'] ??
              image['file_url'] ??
              image['FILE_URL'],
        );

        if (url.isNotEmpty) {
          return url;
        }
      }
    }

    return '';
  }

  // ==========================================================================
  // FILTER
  // ==========================================================================

  void _applyFilter() {
    if (!mounted) {
      return;
    }

    final String query =
    searchController.text
        .trim()
        .toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredProducts =
        List<_DeleteProductRow>.from(
          products,
        );

        filteredMasters =
        List<_DeleteMasterRow>.from(
          masters,
        );

        return;
      }

      filteredProducts =
          products.where((item) {
            return item.itemCode
                .toLowerCase()
                .contains(query) ||
                item.description
                    .toLowerCase()
                    .contains(query) ||
                item.productCategory
                    .toLowerCase()
                    .contains(query) ||
                item.business
                    .toLowerCase()
                    .contains(query) ||
                item.subCategory
                    .toLowerCase()
                    .contains(query) ||
                item.displayRoomNo
                    .toLowerCase()
                    .contains(query) ||
                item.displayRoomName
                    .toLowerCase()
                    .contains(query) ||
                (item.detailSl
                    ?.toString()
                    .contains(query) ??
                    false) ||
                (item.masterSl
                    ?.toString()
                    .contains(query) ??
                    false);
          }).toList();

      filteredMasters =
          masters.where((item) {
            return item.business
                .toLowerCase()
                .contains(query) ||
                item.subCategory
                    .toLowerCase()
                    .contains(query) ||
                item.displayRoomNo
                    .toLowerCase()
                    .contains(query) ||
                item.displayRoomName
                    .toLowerCase()
                    .contains(query) ||
                item.organizationCode
                    .toLowerCase()
                    .contains(query) ||
                (item.organizationId
                    ?.toString()
                    .contains(query) ??
                    false) ||
                (item.masterSl
                    ?.toString()
                    .contains(query) ??
                    false);
          }).toList();
    });
  }

  // ==========================================================================
  // DELETE SINGLE PRODUCT
  // ==========================================================================

  Future<void> _confirmDeleteProduct(
      _DeleteProductRow item,
      ) async {
    if (item.detailSl == null) {
      _showMessage(
        'এই item-এর DETAILS.SL পাওয়া যায়নি। Delete করা যাবে না।',
        isError: true,
      );
      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 34,
          ),
          title: const Text(
            'Delete Product?',
          ),
          content: Text(
            'Item Code: '
                '${item.itemCode.isEmpty ? '-' : item.itemCode}\n'
                'Description: '
                '${item.description.isEmpty ? '-' : item.description}\n'
                'Detail SL: ${item.detailSl}\n\n'
                'এই product এবং এর সব uploaded image permanently delete হবে.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                Colors.redAccent,
                foregroundColor:
                Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              icon: const Icon(
                Icons.delete_forever_outlined,
              ),
              label: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteProduct(item);
  }

  Future<void> _deleteProduct(
      _DeleteProductRow item,
      ) async {
    final int detailSl =
    item.detailSl!;

    final String key =
        'detail_$detailSl';

    if (deletingKey != null) {
      return;
    }

    setState(() {
      deletingKey = key;
    });

    try {
      final Uri uri =
      Uri.parse(apiUrl).replace(
        queryParameters: {
          'p_detail_sl':
          detailSl.toString(),
        },
      );

      debugPrint('==========================================');
      debugPrint('DELETE PRODUCT');
      debugPrint('URL => $uri');
      debugPrint('DETAIL SL => $detailSl');
      debugPrint('==========================================');

      final response = await http
          .delete(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      )
          .timeout(
        const Duration(seconds: 60),
      );

      debugPrint(
        'DELETE STATUS => ${response.statusCode}',
      );
      debugPrint(
        'DELETE RESPONSE => ${response.body}',
      );

      dynamic decoded;

      try {
        decoded =
            jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final dynamic apiStatus =
      decoded is Map
          ? decoded['status_code']
          : null;

      final String message =
      decoded is Map
          ? decoded['message']
          ?.toString() ??
          ''
          : response.body;

      final bool success =
          response.statusCode >= 200 &&
              response.statusCode < 300 &&
              (
                  apiStatus == null ||
                      apiStatus == 200 ||
                      apiStatus.toString() ==
                          '200'
              );

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          message.isEmpty
              ? 'Delete failed.'
              : message,
          isError: true,
        );
        return;
      }

      _showMessage(
        message.isEmpty
            ? 'Product deleted successfully.'
            : message,
      );

      await _loadDeleteData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Delete failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingKey = null;
        });
      }
    }
  }

  // ==========================================================================
  // DELETE COMPLETE MASTER
  // ==========================================================================

  Future<void> _confirmDeleteMaster(
      _DeleteMasterRow item,
      ) async {
    if (item.masterSl == null) {
      _showMessage(
        'এই master-এর SL পাওয়া যায়নি। Delete করা যাবে না।',
        isError: true,
      );
      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 36,
          ),
          title: const Text(
            'Delete Entire Master?',
          ),
          content: Text(
            'Master SL: ${item.masterSl}\n'
                'Display Room: '
                '${item.displayRoomName.isEmpty ? '-' : item.displayRoomName}\n'
                'Products: ${item.detailsCount}\n\n'
                'এতে master record, সব products এবং সব uploaded image permanently delete হবে.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                Colors.redAccent,
                foregroundColor:
                Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              icon: const Icon(
                Icons.delete_forever_outlined,
              ),
              label: const Text(
                'Delete All',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteMaster(item);
  }

  Future<void> _deleteMaster(
      _DeleteMasterRow item,
      ) async {
    final int masterSl =
    item.masterSl!;

    final String key =
        'master_$masterSl';

    if (deletingKey != null) {
      return;
    }

    setState(() {
      deletingKey = key;
    });

    try {
      final Uri uri =
      Uri.parse(apiUrl).replace(
        queryParameters: {
          'p_master_sl':
          masterSl.toString(),
        },
      );

      debugPrint('==========================================');
      debugPrint('DELETE MASTER');
      debugPrint('URL => $uri');
      debugPrint('MASTER SL => $masterSl');
      debugPrint('==========================================');

      final response = await http
          .delete(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      )
          .timeout(
        const Duration(seconds: 60),
      );

      debugPrint(
        'DELETE STATUS => ${response.statusCode}',
      );
      debugPrint(
        'DELETE RESPONSE => ${response.body}',
      );

      dynamic decoded;

      try {
        decoded =
            jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final dynamic apiStatus =
      decoded is Map
          ? decoded['status_code']
          : null;

      final String message =
      decoded is Map
          ? decoded['message']
          ?.toString() ??
          ''
          : response.body;

      final bool success =
          response.statusCode >= 200 &&
              response.statusCode < 300 &&
              (
                  apiStatus == null ||
                      apiStatus == 200 ||
                      apiStatus.toString() ==
                          '200'
              );

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          message.isEmpty
              ? 'Master delete failed.'
              : message,
          isError: true,
        );
        return;
      }

      _showMessage(
        message.isEmpty
            ? 'Master deleted successfully.'
            : message,
      );

      await _loadDeleteData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Master delete failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingKey = null;
        });
      }
    }
  }

  // ==========================================================================
  // UI HELPERS
  // ==========================================================================

  Widget _buildProductImage(
      String imageUrl,
      ) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (
            context,
            error,
            stackTrace,
            ) {
          return Container(
            width: 76,
            height: 76,
            color:
            Colors.grey.shade100,
            alignment:
            Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(
      _DeleteProductRow item,
      ) {
    final String key =
        'detail_${item.detailSl}';

    final bool deleting =
        deletingKey == key;

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 0,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
        side: BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildProductImage(
              item.imageUrl,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description
                        .isNotEmpty
                        ? item.description
                        : item.itemCode
                        .isNotEmpty
                        ? item.itemCode
                        : 'Unnamed Product',
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    item.itemCode.isEmpty
                        ? 'Item Code: -'
                        : 'Item Code: ${item.itemCode}',
                    style:
                    TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _deleteChip(
                        'Detail SL: '
                            '${item.detailSl ?? '-'}',
                      ),
                      _deleteChip(
                        'Master SL: '
                            '${item.masterSl ?? '-'}',
                      ),
                      if (item
                          .productCategory
                          .isNotEmpty)
                        _deleteChip(
                          item.productCategory,
                        ),
                      if (item
                          .business
                          .isNotEmpty)
                        _deleteChip(
                          item.business,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            SizedBox(
              height: 40,
              child:
              FilledButton.icon(
                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  Colors.redAccent,
                  foregroundColor:
                  Colors.white,
                ),
                onPressed:
                deletingKey != null
                    ? null
                    : () {
                  _confirmDeleteProduct(
                    item,
                  );
                },
                icon: deleting
                    ? const SizedBox(
                  width: 17,
                  height: 17,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .delete_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  deleting
                      ? 'Deleting...'
                      : 'Delete',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterCard(
      _DeleteMasterRow item,
      ) {
    final String key =
        'master_${item.masterSl}';

    final bool deleting =
        deletingKey == key;

    final String title =
    item.displayRoomName
        .isNotEmpty
        ? item.displayRoomName
        : item.displayRoomNo
        .isNotEmpty
        ? item.displayRoomNo
        : 'Master '
        '${item.masterSl ?? '-'}';

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 0,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
        side: BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
              BoxDecoration(
                color:
                Colors.red.shade50,
                borderRadius:
                BorderRadius
                    .circular(14),
              ),
              child: const Icon(
                Icons
                    .delete_sweep_outlined,
                color:
                Colors.redAccent,
                size: 28,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    item.displayRoomNo
                        .isEmpty
                        ? 'Master SL: '
                        '${item.masterSl ?? '-'}'
                        : item.displayRoomNo,
                    style:
                    TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _deleteChip(
                        'Master SL: '
                            '${item.masterSl ?? '-'}',
                      ),
                      _deleteChip(
                        'Products: '
                            '${item.detailsCount}',
                      ),
                      if (item.business
                          .isNotEmpty)
                        _deleteChip(
                          item.business,
                        ),
                      if (item
                          .organizationCode
                          .isNotEmpty)
                        _deleteChip(
                          item.organizationCode,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            SizedBox(
              height: 40,
              child:
              FilledButton.icon(
                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  Colors.redAccent,
                  foregroundColor:
                  Colors.white,
                ),
                onPressed:
                deletingKey != null
                    ? null
                    : () {
                  _confirmDeleteMaster(
                    item,
                  );
                },
                icon: deleting
                    ? const SizedBox(
                  width: 17,
                  height: 17,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .delete_forever_outlined,
                  size: 18,
                ),
                label: Text(
                  deleting
                      ? 'Deleting...'
                      : 'Delete All',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleteChip(
      String text,
      ) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
        BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          fontSize: 11,
        ),
      ),
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor:
        isError
            ? Colors.red
            : Colors.green,
        content: Text(message),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title:
          const Text(
            'Delete Display Room Data',
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed:
              isLoading ||
                  deletingKey !=
                      null
                  ? null
                  : _loadDeleteData,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom:
          const TabBar(
            tabs: [
              Tab(
                icon: Icon(
                  Icons
                      .inventory_2_outlined,
                ),
                text: 'Products',
              ),
              Tab(
                icon: Icon(
                  Icons
                      .delete_sweep_outlined,
                ),
                text: 'Masters',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ================================================================
            // WARNING
            // ================================================================
            Container(
              width:
              double.infinity,
              margin:
              const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                0,
              ),
              padding:
              const EdgeInsets.all(12),
              decoration:
              BoxDecoration(
                color:
                Colors.red.shade50,
                borderRadius:
                BorderRadius
                    .circular(12),
                border: Border.all(
                  color:
                  Colors.red.shade100,
                ),
              ),
              child: const Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons
                        .warning_amber_rounded,
                    color:
                    Colors.redAccent,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delete operation permanent. '
                          'Product delete করলে ওই product + images delete হবে. '
                          'Master delete করলে master-এর সব products + images delete হবে.',
                      style:
                      TextStyle(
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // SEARCH
            // ================================================================
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                10,
              ),
              child: TextField(
                controller:
                searchController,
                decoration:
                InputDecoration(
                  hintText:
                  'Search item code, description, room, SL...',
                  prefixIcon:
                  const Icon(
                    Icons.search_rounded,
                  ),
                  suffixIcon:
                  searchController
                      .text
                      .isNotEmpty
                      ? IconButton(
                    onPressed: () {
                      searchController
                          .clear();
                    },
                    icon:
                    const Icon(
                      Icons
                          .close_rounded,
                    ),
                  )
                      : null,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(
                child:
                CircularProgressIndicator(),
              )
                  : TabBarView(
                children: [
                  // ====================================================
                  // PRODUCTS
                  // ====================================================
                  RefreshIndicator(
                    onRefresh:
                    _loadDeleteData,
                    child:
                    filteredProducts
                        .isEmpty
                        ? ListView(
                      physics:
                      const AlwaysScrollableScrollPhysics(),
                      children:
                      const [
                        SizedBox(
                          height:
                          180,
                        ),
                        Icon(
                          Icons
                              .inventory_2_outlined,
                          size:
                          60,
                          color:
                          Colors.grey,
                        ),
                        SizedBox(
                          height:
                          12,
                        ),
                        Center(
                          child:
                          Text(
                            'No products found.',
                          ),
                        ),
                      ],
                    )
                        : ListView
                        .builder(
                      physics:
                      const AlwaysScrollableScrollPhysics(),
                      padding:
                      const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        30,
                      ),
                      itemCount:
                      filteredProducts.length,
                      itemBuilder:
                          (
                          context,
                          index,
                          ) {
                        return _buildProductCard(
                          filteredProducts[index],
                        );
                      },
                    ),
                  ),

                  // ====================================================
                  // MASTERS
                  // ====================================================
                  RefreshIndicator(
                    onRefresh:
                    _loadDeleteData,
                    child:
                    filteredMasters
                        .isEmpty
                        ? ListView(
                      physics:
                      const AlwaysScrollableScrollPhysics(),
                      children:
                      const [
                        SizedBox(
                          height:
                          180,
                        ),
                        Icon(
                          Icons
                              .delete_sweep_outlined,
                          size:
                          60,
                          color:
                          Colors.grey,
                        ),
                        SizedBox(
                          height:
                          12,
                        ),
                        Center(
                          child:
                          Text(
                            'No master records found.',
                          ),
                        ),
                      ],
                    )
                        : ListView
                        .builder(
                      physics:
                      const AlwaysScrollableScrollPhysics(),
                      padding:
                      const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        30,
                      ),
                      itemCount:
                      filteredMasters.length,
                      itemBuilder:
                          (
                          context,
                          index,
                          ) {
                        return _buildMasterCard(
                          filteredMasters[index],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController
        .removeListener(
      _applyFilter,
    );
    searchController.dispose();
    super.dispose();
  }
}

// ============================================================================
// DELETE PAGE SUPPORT MODELS
// ============================================================================

class _DeleteParsedData {
  final List<_DeleteProductRow> products;
  final List<_DeleteMasterRow> masters;

  const _DeleteParsedData({
    required this.products,
    required this.masters,
  });
}

class _DeleteProductRow {
  final int? detailSl;
  final int? masterSl;
  final String itemCode;
  final String description;
  final String productCategory;
  final String business;
  final String subCategory;
  final String displayRoomNo;
  final String displayRoomName;
  final String imageUrl;

  const _DeleteProductRow({
    required this.detailSl,
    required this.masterSl,
    required this.itemCode,
    required this.description,
    required this.productCategory,
    required this.business,
    required this.subCategory,
    required this.displayRoomNo,
    required this.displayRoomName,
    required this.imageUrl,
  });
}

class _DeleteMasterRow {
  final int? masterSl;
  final String business;
  final String subCategory;
  final String displayRoomNo;
  final String displayRoomName;
  final String organizationCode;
  final int? organizationId;
  final String status;
  final int detailsCount;

  const _DeleteMasterRow({
    required this.masterSl,
    required this.business,
    required this.subCategory,
    required this.displayRoomNo,
    required this.displayRoomName,
    required this.organizationCode,
    required this.organizationId,
    required this.status,
    required this.detailsCount,
  });
}

String _asText(dynamic value) {
  return value?.toString().trim() ?? '';
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }

  final String text =
  value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  return int.tryParse(text) ??
      double.tryParse(text)?.toInt();
}

class DisplayRoomItem {
  final int? sl;
  final int? masterSl;
  final String business;
  final String subCategory;
  final int? organizationId;
  final String organizationCode;
  final String displayRoomNo;
  final String displayRoomName;
  final String status;
  final int? assignee;
  final int? createdBy;
  final int? updatedBy;
  final String sourceSl;
  final String productCategory;
  final String printValue;
  final String itemQrCode;
  final String fileUrl;
  final String fileName;
  final String mimeType;
  final String itemCode;
  final String description;
  final String uom;
  final double? quantity;
  final double? unitPrice;
  final String subInventoryCode;
  final int? locatorId;
  final String cbm;
  final double? fob;
  final double? weight;
  final String materialSpecification;

  const DisplayRoomItem({
    required this.sl,
    required this.masterSl,
    required this.business,
    required this.subCategory,
    required this.organizationId,
    required this.organizationCode,
    required this.displayRoomNo,
    required this.displayRoomName,
    required this.status,
    required this.assignee,
    required this.createdBy,
    required this.updatedBy,
    required this.sourceSl,
    required this.productCategory,
    required this.printValue,
    required this.itemQrCode,
    required this.fileUrl,
    required this.fileName,
    required this.mimeType,
    required this.itemCode,
    required this.description,
    required this.uom,
    required this.quantity,
    required this.unitPrice,
    required this.subInventoryCode,
    required this.locatorId,
    required this.cbm,
    required this.fob,
    required this.weight,
    required this.materialSpecification,
  });

  factory DisplayRoomItem.fromJson(Map<String, dynamic> json) {
    dynamic v(String lower, String upper) => json[lower] ?? json[upper];

    final note = _text(v('note', 'NOTE'));

    return DisplayRoomItem(
      sl: _int(v('sl', 'SL')),
      masterSl: _int(v('m_sl', 'M_SL')),
      business: _text(v('business', 'BUSINESS')),
      subCategory: _text(v('sub_category', 'SUB_CATEGORY')),
      organizationId: _int(v('organization_id', 'ORGANIZATION_ID')),
      organizationCode: _text(v('organization_code', 'ORGANIZATION_CODE')),
      displayRoomNo: _text(v('display_room_no', 'DISPLAY_ROOM_NO')),
      displayRoomName: _text(v('display_room_name', 'DISPLAY_ROOM_NAME')),
      status: _text(v('status', 'STATUS')),
      assignee: _int(v('assignee', 'ASSIGNEE')),
      createdBy: _int(v('created_by', 'CREATED_BY')),
      updatedBy: _int(v('updated_by', 'UPDATED_BY')),
      sourceSl: _extractNote(note, 'SOURCE_SL'),
      productCategory: _text(v('product_category', 'PRODUCT_CATEGORY')),
      printValue: _extractNote(note, 'PRINT'),
      itemQrCode: _extractNote(note, 'ITEM_QRCODE'),
      fileUrl: _text(v('file_url', 'FILE_URL')),
      fileName: _text(v('file_name', 'FILE_NAME')),
      mimeType: _text(v('mime_type', 'MIME_TYPE')),
      itemCode: _text(v('item_code', 'ITEM_CODE')),
      description: _text(v('description', 'DESCRIPTION')),
      uom: _text(v('uom', 'UOM')),
      quantity: _double(v('quantity', 'QUANTITY')),
      unitPrice: _double(v('unit_price', 'UNIT_PRICE')),
      subInventoryCode:
      _text(v('sub_inventory_code', 'SUB_INVENTORY_CODE')),
      locatorId: _int(v('locator_id', 'LOCATOR_ID')),
      cbm: _text(v('cbm', 'CBM')),
      fob: _double(v('fob', 'FOB')),
      weight: _double(v('weight', 'WEIGHT')),
      materialSpecification:
      _text(v('material_specification', 'MATERIAL_SPECIFICATION')),
    );
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int? _int(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.toInt();
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static String _extractNote(String note, String key) {
    if (note.isEmpty) return '';

    for (final part in note.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;

      final currentKey = part.substring(0, index).trim().toUpperCase();
      if (currentKey == key.toUpperCase()) {
        return part.substring(index + 1).trim();
      }
    }

    return '';
  }
}