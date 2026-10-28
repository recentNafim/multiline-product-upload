import 'dart:convert';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../services/display_room_api_service.dart';
import '../../utils/excel_value_utils.dart';
import '../../utils/excel_embedded_pictures.dart';
import '../../utils/auto_image_file_name.dart';
import '../../utils/image_resolution.dart';
import '../../widgets/common_form_widgets.dart';
import '../../widgets/excel_data_table_preview.dart';

class ItemUploadScreen extends StatefulWidget {
  const ItemUploadScreen({super.key});

  @override
  State<ItemUploadScreen> createState() =>
      _ItemUploadScreenState();
}

class _ItemUploadScreenState extends State<ItemUploadScreen> {
  static const String apiUrl = ApiConstants.uploadItem;

  // Fixed UI choices only. The API payload and Oracle column names stay unchanged:
  // Category -> master.business, Sub Category -> master.sub_category.
  // Detail 'Item Category' remains the existing editable product_category field.
  static const List<String> _categoryOptions = <String>[
    'Footwear',
    'Bag & Luggage',
    'Tent',
    'Umbrella',
    'Handicraft',
  ];
  static const List<String> _subCategoryOptions = <String>[
    'Export', 'Domestic',
  ];

  String? _matchingFixedChoice(String text, List<String> choices) {
    final value = text.trim().toLowerCase();
    for (final choice in choices) {
      if (choice.toLowerCase() == value) return choice;
    }
    return null;
  }

  Widget _buildFixedDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> choices,
    bool isRequired = true,
  }) {
    final selected = _matchingFixedChoice(controller.text, choices);
    return DropdownButtonFormField<String>(
      // Excel import and form reset also update this controller.
      key: ValueKey<String>('fixed-$label-${controller.text.trim()}'),
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select $label',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: !isRequired && controller.text.trim().isNotEmpty
            ? IconButton(
                tooltip: 'Clear $label',
                icon: const Icon(Icons.close, size: 18),
                onPressed: isLoading ? null : () {
                  setState(controller.clear);
                },
              )
            : null,
      ),
      items: choices.map((value) => DropdownMenuItem<String>(
        value: value,
        child: Text(value, overflow: TextOverflow.ellipsis),
      )).toList(),
      validator: (value) => isRequired && value == null
          ? '$label is required'
          : null,
      onChanged: isLoading ? null : (value) {
        if (value != null) {
          setState(() => controller.text = value);
        }
      },
    );
  }


  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isReadingExcel = false;

  String? selectedExcelName;

  // Remains visible after the upload form is cleared.
  String? _submissionNotice;

  /// Excel select করলে API payload-এর জন্য mapped detail এখানে থাকবে।
  List<Map<String, dynamic>> excelDetails = [];

  /// Excel-এর raw normalized headers এবং rows DataTable preview-এর জন্য।
  List<String> excelTableHeaders = [];
  List<Map<String, dynamic>> excelTableRows = [];


  // ============================================================
  // IMAGE STATE
  // ============================================================

  /// Manual item-এর জন্য সর্বোচ্চ 5টি image।
  final List<PlatformFile> selectedImages = [];

  /// Excel mode-এ IMAGE column-এর filename-এর সাথে match করার জন্য
  /// একসাথে অনেক image file select করা যাবে। Backend limit প্রতি item-এ 5।
  final List<PlatformFile> selectedExcelImages = [];

  // Original full-resolution files override embedded Excel thumbnails.
  // Key is the automatically generated Excel SERIAL, not a filename.
  // No extra Excel column or user-entered filename is needed.
  final Map<int, List<PlatformFile>> originalExcelPhotosBySerial = {};
  final Map<int, List<String>> originalExcelPhotoDimensions = {};
  int? readingOriginalPhotosForSerial;

  bool isReadingImages = false;
  bool isReadingExcelImages = false;

  // ============================================================
  // 3D MODEL STATE
  // ============================================================

  /// Manual mode-এ প্রতি item-এর জন্য optional 1টি .glb model।
  PlatformFile? selected3DModel;

  /// Excel mode-এ প্রতিটি row-এর 3D MODEL filename-এর সাথে match করবে।
  final List<PlatformFile> selectedExcel3DModels = [];

  bool isReading3DModel = false;
  bool isReadingExcel3DModels = false;

  // ============================================================
  // MASTER CONTROLLERS
  // ============================================================

  final businessController = TextEditingController();
  final subCategoryController = TextEditingController();
  final organizationIdController = TextEditingController();
  final displayRoomNameController = TextEditingController();
  final createdByController = TextEditingController();
  final statusController = TextEditingController();
  final assigneeController = TextEditingController();

  // ============================================================
  // DETAIL CONTROLLERS
  // Current API/UI fields only
  // ============================================================

  final productCategoryController = TextEditingController();
  final itemCodeController = TextEditingController();
  final descriptionController = TextEditingController();
  final uomController = TextEditingController();
  final subInventoryCodeController = TextEditingController();
  final cbmController = TextEditingController();
  final fobController = TextEditingController();
  final materialSpecificationController = TextEditingController();
  final weightController = TextEditingController();
  final sizeRangeController = TextEditingController();
  final moqController = TextEditingController();

  @override
  void initState() {
    super.initState();
    statusController.text = 'ACTIVE';
  }

  // ============================================================
  // EXCEL HELPERS
  // ============================================================







  // ============================================================
  // IMAGE HELPERS
  // ============================================================



  List<Map<String, dynamic>> _manualImagesPayload() {
    return selectedImages
        .where((file) => file.bytes != null)
        .map(platformFileToImageJson)
        .toList();
  }

  List<Map<String, dynamic>> _excelImagesPayloadForDetail(
      Map<String, dynamic> detail,
      ) {
    final int serial = asInt(detail['_excel_serial']) ?? 0;
    final originals = originalExcelPhotosBySerial[serial];
    if (originals != null && originals.isNotEmpty) {
      // EXACT original selected bytes. No resizing, thumbnail extraction,
      // recompression, image conversion, or quality reduction.
      return originals.map(platformFileToImageJson).toList();
    }
    final rawNames = detail['_image_names'];

    final List<String> expectedNames = rawNames is List
        ? rawNames
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList()
        : <String>[];

    if (expectedNames.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    // Follow the order of images in this Excel row (not the order in which
    // files were selected); this determines image number 01, 02, ...
    final filesByName = <String, PlatformFile>{
      for (final file in selectedExcelImages)
        if (file.bytes != null) file.name.toLowerCase(): file,
    };
    return expectedNames
        .map((name) => filesByName[name.toLowerCase()])
        .whereType<PlatformFile>()
        .take(5)
        .map(platformFileToImageJson)
        .toList();
  }

  /// Stops silent low-quality uploads. Existing Excel cells may contain
  /// thumbnail JPEGs (e.g. 92x69) even though Excel draws them quite large.
  /// Let the user explicitly continue only after seeing the real dimensions.
  Future<bool> _confirmImageQualityBeforeUpload() async {
    final bool excelMode = excelDetails.isNotEmpty;
    final List<PlatformFile> files;
    if (excelMode) {
      final filesByName = <String, PlatformFile>{
        for (final file in selectedExcelImages)
          if (file.bytes != null) file.name.toLowerCase(): file,
      };
      files = <PlatformFile>[
        for (final detail in excelDetails)
          ...(() {
            final serial = asInt(detail['_excel_serial']) ?? 0;
            final originals = originalExcelPhotosBySerial[serial];
            if (originals != null && originals.isNotEmpty) {
              return originals;
            }
            final names = detail['_image_names'];
            return <PlatformFile>[
              if (names is List)
                for (final name in names)
                  if (filesByName[name.toString().toLowerCase()] != null)
                    filesByName[name.toString().toLowerCase()]!,
            ];
          })(),
      ];
    } else {
      files = List<PlatformFile>.from(selectedImages);
    }

    final issues = <String>[];
    for (final file in files) {
      final resolution = await readImageResolution(file.bytes);
      if (resolution != null && resolution.isLowResolution) {
        issues.add('${file.name}: ${resolution.width} x ${resolution.height}');
      }
    }
    if (issues.isEmpty) return true;
    if (!mounted) return false;

    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Low-resolution pictures')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Text(
              'These pictures are too small for the Dashboard:\n\n'
              '${issues.take(8).join('\n')}'
              '${issues.length > 8 ? '\n...and ${issues.length - 8} more' : ''}'
              '\n\nFor sharp product pictures, use the original JPG/PNG '
              '(preferably 1200x900 pixels or better). '
              'If they were pasted from a thumbnail, replace them in Excel '
              'using Insert > Pictures > This Device.\n\n'
              'You may still upload, but the resulting image will remain blurry.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel - replace pictures'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Upload anyway'),
          ),
        ],
      ),
    );
    return decision == true;
  }

  // ============================================================
  // 3D MODEL HELPERS
  // ============================================================

  Map<String, dynamic>? _platformFileTo3DModelJson(PlatformFile? file) {
    if (file == null || file.bytes == null) {
      return null;
    }

    return <String, dynamic>{
      'file_base64': base64Encode(file.bytes!),
      'file_name': file.name,
      'mime_type': 'model/gltf-binary',
    };
  }

  String _modelNameFromExcelRow(Map<String, dynamic> row) {
    const possibleHeaders = <String>[
      '3D MODEL',
      '3D MODEL FILE',
      'MODEL 3D',
      'GLB',
      'GLB FILE',
    ];

    for (final header in possibleHeaders) {
      final value = asText(row[header]);
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  Map<String, dynamic>? _excel3DModelPayloadForDetail(
      Map<String, dynamic> detail,
      ) {
    final expectedName =
        detail['_model_3d_name']?.toString().trim() ?? '';

    if (expectedName.isEmpty) {
      return null;
    }

    PlatformFile? matchedFile;

    for (final file in selectedExcel3DModels) {
      if (file.name.toLowerCase() == expectedName.toLowerCase()) {
        matchedFile = file;
        break;
      }
    }

    return _platformFileTo3DModelJson(matchedFile);
  }

  List<String> _missingExcel3DModelFiles() {
    final expectedNames = excelDetails
        .map(
          (detail) =>
      detail['_model_3d_name']?.toString().trim() ?? '',
    )
        .where((name) => name.isNotEmpty)
        .toSet();

    if (expectedNames.isEmpty) {
      return <String>[];
    }

    final selectedNames = selectedExcel3DModels
        .where((file) => file.bytes != null)
        .map((file) => file.name.toLowerCase())
        .toSet();

    return expectedNames
        .where((name) => !selectedNames.contains(name.toLowerCase()))
        .toList();
  }

  Future<void> selectManual3DModel() async {
    try {
      setState(() {
        isReading3DModel = true;
      });

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['glb'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) {
        return;
      }

      final file = result.files.single;

      if (file.bytes == null) {
        showError('Selected .glb file read করা যাচ্ছে না।');
        return;
      }

      if (!file.name.toLowerCase().endsWith('.glb')) {
        showError('শুধু .glb 3D model select করা যাবে।');
        return;
      }

      setState(() {
        selected3DModel = file;
      });
    } catch (e) {
      showError('3D model select failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isReading3DModel = false;
        });
      }
    }
  }

  Future<void> selectExcel3DModels() async {
    try {
      setState(() {
        isReadingExcel3DModels = true;
      });

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['glb'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null) {
        return;
      }

      final validFiles = result.files
          .where(
            (file) =>
        file.bytes != null &&
            file.name.toLowerCase().endsWith('.glb'),
      )
          .toList();

      if (validFiles.isEmpty) {
        showError('Valid .glb file পাওয়া যায়নি।');
        return;
      }

      final Map<String, PlatformFile> merged = {
        for (final file in selectedExcel3DModels)
          file.name.toLowerCase(): file,
        for (final file in validFiles)
          file.name.toLowerCase(): file,
      };

      setState(() {
        selectedExcel3DModels
          ..clear()
          ..addAll(merged.values);
      });
    } catch (e) {
      showError('Excel 3D model select failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isReadingExcel3DModels = false;
        });
      }
    }
  }

  void removeManual3DModel() {
    setState(() {
      selected3DModel = null;
    });
  }

  void clearExcel3DModels() {
    setState(() {
      selectedExcel3DModels.clear();
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
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

  Future<void> selectOriginalExcelPhotos(int excelSerial) async {
    if (excelDetails.isEmpty || isLoading || readingOriginalPhotosForSerial != null) {
      return;
    }
    setState(() => readingOriginalPhotosForSerial = excelSerial);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        allowMultiple: true,
        withData: true, // Preserve the selected source image's original bytes.
      );
      if (result == null) return;
      if (result.files.isEmpty || result.files.length > 5) {
        showError('Choose 1 to 5 original JPG/PNG images for this Excel row.');
        return;
      }
      final photos = <PlatformFile>[];
      final dimensions = <String>[];
      for (final file in result.files) {
        if (file.bytes == null || file.bytes!.isEmpty) {
          showError('Could not read ${file.name}; select the original photo again.');
          return;
        }
        if (file.size > 12 * 1024 * 1024) {
          showError('${file.name} exceeds 12 MB. Use an original under 12 MB.');
          return;
        }
        final size = await readImageResolution(file.bytes);
        if (size == null) {
          showError('Unsupported image or corrupted image: ${file.name}');
          return;
        }
        photos.add(file);
        dimensions.add('${size.width} x ${size.height} px'
            '${size.isLowResolution ? ' (LOW RESOLUTION)' : ''}');
      }
      if (!mounted) return;
      setState(() {
        originalExcelPhotosBySerial[excelSerial] = photos;
        originalExcelPhotoDimensions[excelSerial] = dimensions;
      });
    } catch (error) {
      if (mounted) showError('Original picture selection failed: $error');
    } finally {
      if (mounted) {
        setState(() => readingOriginalPhotosForSerial = null);
      }
    }
  }

  void clearOriginalExcelPhotos(int excelSerial) {
    setState(() {
      originalExcelPhotosBySerial.remove(excelSerial);
      originalExcelPhotoDimensions.remove(excelSerial);
    });
  }

  void removeManualImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
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

      // Embedded Excel pictures have no cell value. Match drawing anchors to
      // the PICTURE column, then reuse the normal image upload pipeline.
      final pictureColumnIndex = headers.indexOf('PICTURE') >= 0
          ? headers.indexOf('PICTURE')
          : headers.indexOf('IMAGE');
      final embeddedPictures = readExcelEmbeddedPictures(
        file.bytes!,
        pictureColumnIndex: pictureColumnIndex,
      );
      final embeddedFilesUsed = <PlatformFile>[];

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

        if (asText(row['ITEM CATEGORY']).isEmpty) {
          row['ITEM CATEGORY'] = row['PRODUCT CATEGORY'];
        }
        if (asText(row['ITEM NAME']).isEmpty) {
          row['ITEM NAME'] = row['DESCRIPTION'];
        }
        // ITEM CODE is optional: accept a blank cell or an entirely absent
        // ITEM CODE column. Keep a normalized empty string for the preview
        // and API payload rather than treating it as a validation failure.
        row['ITEM CODE'] = asText(row['ITEM CODE']);
        if (asText(row['ORG']).isEmpty) {
          row['ORG'] = row['ORGANIZATION ID'];
        }
        if (asText(row['PICTURE']).isEmpty) {
          row['PICTURE'] = row['IMAGE'];
        }
        // The user may paste a real JPEG/PNG object directly on the cell.
        // When no filename is supplied, import its bytes automatically.
        final inlinePictures = embeddedPictures[rowIndex] ?? <PlatformFile>[];
        if (inlinePictures.isNotEmpty) {
          // Embedded pictures take precedence over any text or old filename.
          // The user does not need to type a picture filename in Excel.
          row['PICTURE'] = inlinePictures.map((f) => f.name).join(';');
          embeddedFilesUsed.addAll(inlinePictures);
        }
        // Ignore only fully blank rows, after considering embedded images.
        if (row.values.every((value) => asText(value).isEmpty)) {
          continue;
        }
        row['SERIAL'] = rows.length + 1; // Preview sequence, never DB PK.
        rows.add(row);
      }

      if (rows.isEmpty) {
        throw Exception('Excel file-এ valid item পাওয়া যায়নি');
      }

      // Validate the ENTIRE workbook before a single POST. The API accepts
      // one master business/organization per request; reject mixed files.
      final failures = <String>[];
      final firstBusiness = asText(rows.first['BUSINESS']).toLowerCase();
      final firstOrg = asInt(rows.first['ORG']);
      for (int index = 0; index < rows.length; index++) {
        final row = rows[index];
        final missing = <String>[];
        for (final key in const <String>[
          'BUSINESS', 'ITEM CATEGORY', 'ORG',
          'FOB', 'SIZE RANGE', 'MOQ',
        ]) {
          if (asText(row[key]).isEmpty) missing.add(key);
        }
        if (missing.isNotEmpty) {
          failures.add('Row ${index + 2}: missing ${missing.join(', ')}');
        }
        // Item code is optional. A readable item name is required only
        // when the code is absent, so Oracle can identify the product.
        if (asText(row['ITEM CODE']).isEmpty &&
            asText(row['ITEM NAME']).isEmpty) {
          failures.add('Row ${index + 2}: ITEM NAME is required when ITEM CODE is empty');
        }
        final weightText = asText(row['WEIGHT']);
        if (weightText.isNotEmpty &&
            (asDouble(row['WEIGHT']) == null || asDouble(row['WEIGHT'])! < 0)) {
          failures.add('Row ${index + 2}: WEIGHT must be a non-negative number in grams (g)');
        }
        if (asText(row['ORG']).isNotEmpty && (asInt(row['ORG']) == null ||
            asDouble(row['ORG']) != asInt(row['ORG'])!.toDouble())) {
          failures.add('Row ${index + 2}: ORG must be a numeric organization ID');
        }
        final fobText = asText(row['FOB']);
        if (fobText.isNotEmpty &&
            (asDouble(row['FOB']) == null || asDouble(row['FOB'])! < 0)) {
          failures.add('Row ${index + 2}: FOB must be a non-negative number');
        }
        final moqText = asText(row['MOQ']);
        if (moqText.isNotEmpty &&
            (asDouble(row['MOQ']) == null || asDouble(row['MOQ'])! <= 0)) {
          failures.add('Row ${index + 2}: MOQ must be greater than zero');
        }
         final sizeRangeIssue = validateSizeRange(row['SIZE RANGE']);
         if (sizeRangeIssue != null) {
           failures.add('Row ${index + 2}: $sizeRangeIssue');
         }
        if (asText(row['BUSINESS']).toLowerCase() != firstBusiness ||
            asInt(row['ORG']) != firstOrg) {
          failures.add('Row ${index + 2}: Business/ORG differs from the first row');
        }
        if (imageNamesFromExcelValue(row['PICTURE']).length > 5) {
          failures.add('Row ${index + 2}: maximum 5 pictures per product');
        }
      }
      if (failures.isNotEmpty) {
        throw FormatException('Excel validation failed:\n${failures.take(15).join('\n')}');
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
      // Canonicalize Excel spelling when it matches a fixed UI choice.
      businessController.text = _matchingFixedChoice(
        businessController.text, _categoryOptions,
      ) ?? businessController.text;
      subCategoryController.text = _matchingFixedChoice(
        subCategoryController.text, _subCategoryOptions,
      ) ?? subCategoryController.text;

      setControllerIfAvailable(
        displayRoomNameController,
        firstRow['DISPLAY ROOM NAME'],
      );

      // The Excel format does not require STAFF ID as a column. It can
      // be entered once in the master form, or auto-filled when supplied.
      setControllerIfAvailable(
        createdByController,
        firstRow['STAFF ID'] ?? firstRow['CREATED BY'],
      );

      // Excel-এ Organization ID থাকলে fill করবে।
      setControllerIfAvailable(
        organizationIdController,
        firstRow['ORG'],
      );

      // First detail row preview - current visible fields only
      setControllerIfAvailable(
        productCategoryController,
        firstRow['ITEM CATEGORY'],
      );

      // Do not preserve the previous item's code when the newly selected
      // workbook deliberately leaves ITEM CODE blank.
      itemCodeController.text = asText(firstRow['ITEM CODE']);

      setControllerIfAvailable(
        descriptionController,
        firstRow['ITEM NAME'],
      );

      setControllerIfAvailable(
        uomController,
        firstRow['UOM'],
      );

      setControllerIfAvailable(
        subInventoryCodeController,
        firstRow['SUB INVENTORY CODE'],
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

       setControllerIfAvailable(
         sizeRangeController,
         normalizeSizeRange(firstRow['SIZE RANGE']),
       );
      setControllerIfAvailable(moqController, firstRow['MOQ']);

      // ========================================================
      // CREATE ALL EXCEL DETAILS
      // ========================================================

      final details = rows.map((row) {
        final imageNames =
        imageNamesFromExcelValue(row['PICTURE']);

        final model3DName =
        _modelNameFromExcelRow(row);

        if (imageNames.length > 5) {
          throw Exception(
            'Item ${asText(row['ITEM CODE'])}: প্রতি item-এ সর্বোচ্চ 5টি image allowed.',
          );
        }

        return <String, dynamic>{
          "product_category":
          asText(
            row['ITEM CATEGORY'],
          ),

          // Internal helper. API পাঠানোর আগে remove করা হবে।
          "_image_names":
          imageNames,
          // Auto-generated preview SERIAL is the image filename serial.
          // This metadata must never be included in the Oracle POST.
          "_excel_serial": asInt(row['SERIAL']) ?? 1,

          // Excel-এর 3D MODEL / GLB filename.
          // API পাঠানোর আগে actual Base64 payload দিয়ে replace হবে।
          "_model_3d_name":
          model3DName,

          "item_code":
           asText(
             row['ITEM CODE'],
           ),

           // One Excel SIZE RANGE cell -> one Oracle size_range field.
           "size_range": normalizeSizeRange(row['SIZE RANGE']),
           "moq": asDouble(row['MOQ']),
           "quantity": asDouble(row['MOQ']),

          "description":
          asText(
            row['ITEM NAME'],
          ),

          "uom":
          asText(row['UOM']),

          "sub_inventory_code":
          asText(
            row['SUB INVENTORY CODE'],
          ),

          // CBM MUST ALWAYS GO AS JSON STRING
          "cbm": asText(row['CBM']).trim().toString(),

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
        // Reset pictures from a previous workbook. The embedded images are
        // already decoded bytes and DO NOT need separate file selection.
        selectedExcelImages
          ..clear()
          ..addAll(embeddedFilesUsed);
        originalExcelPhotosBySerial.clear();
        originalExcelPhotoDimensions.clear();
        selectedExcelName = file.name;
        excelDetails = details;
        const hiddenLegacyHeaders = <String>{
           'PRINT ITEM', 'QR CODE', 'TRACK MARK', 'FACTORY',
           'ITEM QR CODE', 'TRACKMARK', 'PRINT VALUE', 'SERIAL NO',
           'SERIAL NUMBER', 'SL NO',
          'DISPLAY ROOM NO',
          'ITEM QRCODE',
          'SL',
          'PRINT',
          'QUANTITY',
          'UNIT PRICE',
          'LOCATOR ID',
          'FILE URL',
          'FILE NAME',
          'MIME TYPE',
        };

        excelTableHeaders = <String>['SERIAL', ...headers.where((h) => h != 'SERIAL')]
             .where(
              (header) =>
          header.isNotEmpty &&
              !hiddenLegacyHeaders.contains(header),
        )
            .toList();
        excelTableRows = rows;
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
      if (mounted) {
        showError(e is FormatException ? e.message : e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isReadingExcel = false);
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
      excelTableHeaders = [];
      excelTableRows = [];
      selectedExcelImages.clear();
      originalExcelPhotosBySerial.clear();
      originalExcelPhotoDimensions.clear();
      selectedExcel3DModels.clear();
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
    final model3DPayload =
    _platformFileTo3DModelJson(selected3DModel);

    return {
      "product_category":
      productCategoryController.text.trim(),

      "item_code":
      itemCodeController.text.trim(),

      "description":
      descriptionController.text.trim(),

      "uom":
      uomController.text.trim(),

      "sub_inventory_code":
      subInventoryCodeController.text.trim(),

      // CBM MUST ALWAYS GO AS JSON STRING
      "cbm": cbmController.text.trim().toString(),

      "fob": double.tryParse(
        fobController.text.trim(),
      ),

      "material_specification":
      materialSpecificationController.text.trim(),

      "weight": double.tryParse(
       weightController.text.trim(),
       ),

       "size_range": normalizeSizeRange(sizeRangeController.text),
       "moq": double.tryParse(moqController.text.trim()),
       "quantity": double.tryParse(moqController.text.trim()),

      "images":
      _manualImagesPayload(),

      if (model3DPayload != null)
        "model_3d":
        model3DPayload,
    };
  }


  // ============================================================
  // FINAL API PAYLOAD NORMALIZER
  // ============================================================

  Map<String, dynamic> _normalizeDetailForApi(
      Map<String, dynamic> source,
      ) {
    final detail = Map<String, dynamic>.from(source);

    // IMPORTANT:
    // CBM is TEXT in the API contract. Force it to String even if
    // an Excel parser returns int/double dynamically.
    final cbmValue = detail['cbm'];
    detail['cbm'] = cbmValue == null ? '' : cbmValue.toString().trim();

    // Ensure every Excel and manual detail sends the canonical Oracle
    // SIZE_RANGE field as a trimmed JSON String (never a locator ID).
    // Excel UI validates it as mandatory before this normalization step.
    final String sizeRange = asText(
      detail['size_range'] ?? detail['sizeRange'] ?? detail['SIZE RANGE'],
    ).trim();
     detail['size_range'] = normalizeSizeRange(sizeRange);
    detail.remove('sizeRange');
    detail.remove('SIZE RANGE');

    // FOB and Weight remain numeric.
    final fobValue = detail['fob'];
    if (fobValue is String) {
      final text = fobValue.trim();
      detail['fob'] = text.isEmpty ? null : double.tryParse(text);
    }

    final weightValue = detail['weight'];
    if (weightValue is String) {
      final text = weightValue.trim();
      detail['weight'] = text.isEmpty ? null : double.tryParse(text);
    }

    // Internal upload/Excel metadata must never reach Oracle.
    detail.remove('_excel_serial');

    return detail;
  }

  Map<String, dynamic> _debugSafeBody(
      Map<String, dynamic> body,
      ) {
    final copy = Map<String, dynamic>.from(body);

    final details = (body['details'] as List? ?? const [])
        .map((e) {
      final detail = Map<String, dynamic>.from(
        e as Map,
      );

      final images = detail['images'];
      if (images is List) {
        detail['images'] = images.map((img) {
          final item = Map<String, dynamic>.from(
            img as Map,
          );

          if (item.containsKey('picture_base64')) {
            item['picture_base64'] = '<BASE64_REMOVED>';
          }

          if (item.containsKey('file_base64')) {
            item['file_base64'] = '<BASE64_REMOVED>';
          }

          return item;
        }).toList();
      }

      final model = detail['model_3d'];
      if (model is Map) {
        final modelCopy = Map<String, dynamic>.from(model);

        if (modelCopy.containsKey('file_base64')) {
          modelCopy['file_base64'] = '<BASE64_REMOVED>';
        }

        detail['model_3d'] = modelCopy;
      }

      return detail;
    })
        .toList();

    copy['details'] = details;

    return copy;
  }

  /// Clear all workbook, image and form state ONLY after a confirmed success.
  /// Keep every field unchanged if the request fails so the user can retry.
  void _clearEntryAfterSuccess({required String notice}) {
    final controllers = <TextEditingController>[
      businessController,
      subCategoryController,
      organizationIdController,
      displayRoomNameController,
      createdByController,
      statusController,
      assigneeController,
      productCategoryController,
      itemCodeController,
      descriptionController,
      uomController,
      subInventoryCodeController,
      cbmController,
      fobController,
      materialSpecificationController,
      weightController,
      sizeRangeController,
      moqController,
    ];
    // Reset field errors first: TextFormField.reset() can restore its initial
    // controller value, so controllers must be cleared AFTER FormState.reset().
    _formKey.currentState?.reset();
    for (final controller in controllers) {
      controller.clear();
    }
    statusController.text = 'ACTIVE';
    setState(() {
      selectedExcelName = null;
      excelDetails = <Map<String, dynamic>>[];
      excelTableHeaders = <String>[];
      excelTableRows = <Map<String, dynamic>>[];
      selectedExcelImages.clear();
      originalExcelPhotosBySerial.clear();
      originalExcelPhotoDimensions.clear();
      selectedImages.clear();
      selectedExcel3DModels.clear();
      selected3DModel = null;
      _submissionNotice = notice;
    });
  }

  bool _isConfirmedApiSuccess(http.Response response, dynamic decoded) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    if (decoded is! Map) return true;
    final rawStatus = decoded['status_code'] ?? decoded['STATUS_CODE'];
    if (rawStatus != null &&
        !{'200', '201', '202', '204', 'S', 'SUCCESS'}
            .contains(rawStatus.toString().trim().toUpperCase())) {
      return false;
    }
    final returnStatus = decoded['return_status'] ?? decoded['RETURN_STATUS'];
    if (returnStatus != null &&
        !{'S', 'SUCCESS', '200', '201'}
            .contains(returnStatus.toString().trim().toUpperCase())) {
      return false;
    }
    final explicitSuccess = decoded['success'];
    if (explicitSuccess == false ||
        explicitSuccess?.toString().toLowerCase() == 'false') {
      return false;
    }
    return true;
  }

  /// Shared pre-flight checks for Excel and manual form submissions.
  /// An empty optional ITEM CODE must never block an upload.
  List<String> _collectRequiredFieldErrors() {
    final errors = <String>[];
    final excelMode = excelDetails.isNotEmpty;
    if (_matchingFixedChoice(businessController.text, _categoryOptions) == null) {
      errors.add('Select Category from the dropdown.');
    }
    if (subCategoryController.text.trim().isNotEmpty &&
        _matchingFixedChoice(subCategoryController.text, _subCategoryOptions) == null) {
      errors.add('Select Sub Category from the dropdown.');
    }
    final staffText = createdByController.text.trim();
    final staffId = int.tryParse(staffText);
    if (staffId == null || staffId <= 0) {
      errors.add('Staff ID (Created By) is required and must be a positive number.');
    }
    final organizationText = organizationIdController.text.trim();
    final organizationId = int.tryParse(organizationText);
    if (excelMode && (organizationId == null || organizationId <= 0)) {
      errors.add('Organization ID is required for Excel upload.');
    } else if (organizationText.isNotEmpty &&
        (organizationId == null || organizationId <= 0)) {
      errors.add('Organization ID must be a positive number when provided.');
    }
    final assigneeText = assigneeController.text.trim();
    if (assigneeText.isNotEmpty &&
        (int.tryParse(assigneeText) == null || int.parse(assigneeText) <= 0)) {
      errors.add('Assignee must be a positive numeric Staff ID when provided.');
    }
    if (!excelMode) {
      if (productCategoryController.text.trim().isEmpty) {
        errors.add('Item Category is required.');
      }
      if (itemCodeController.text.trim().isEmpty &&
          descriptionController.text.trim().isEmpty) {
        errors.add('Item Name / Description is required when Item Code is empty.');
      }
      final fob = double.tryParse(fobController.text.trim());
      if (fob == null || fob < 0 || !fob.isFinite) {
        errors.add('FOB is required and must be a non-negative number.');
      }
      final moq = double.tryParse(moqController.text.trim());
      if (moq == null || moq <= 0 || !moq.isFinite) {
        errors.add('MOQ is required and must be greater than zero.');
      }
      final sizeError = validateSizeRange(sizeRangeController.text);
      if (sizeError != null) errors.add('Size Range: $sizeError');
      if (selectedImages.isEmpty) {
        errors.add('Picture is required. Select at least one image.');
      }
    }
    final weightText = weightController.text.trim();
    if (!excelMode && weightText.isNotEmpty) {
      final weight = double.tryParse(weightText);
      if (weight == null || weight < 0 || !weight.isFinite) {
        errors.add('Weight must be a non-negative number in grams (g).');
      }
    }
    return errors;
  }

  // ============================================================
  // API SUBMIT
  // ============================================================

  Future<void> uploadItem() async {
    FocusScope.of(context).unfocus();

    // Always show a human-readable summary. Inline Form validators alone
    // may be off screen for long Excel upload pages.
    final errors = _collectRequiredFieldErrors();
    final validForm = _formKey.currentState?.validate() ?? false;
    if (!validForm || errors.isNotEmpty) {
      showError(errors.isNotEmpty
          ? 'Please fix these fields before submission:\n${errors.join('\n')}'
          : 'Please correct the highlighted fields before submission.');
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

    // Manual upload: Organization ID may be omitted.
    // Excel upload: ORG is still a mandatory workbook column and the
    // organization ID auto-filled from the validated first Excel row.
    final organizationText = organizationIdController.text.trim();
    if (organizationText.isNotEmpty &&
        (organizationId == null || organizationId <= 0)) {
      showError('Valid numeric Organization ID দিন');
      return;
    }
    if (excelDetails.isNotEmpty && organizationId == null) {
      showError('Excel upload-এর জন্য Organization ID required');
      return;
    }

    if (createdBy == null || createdBy <= 0) {
      showError('Staff ID / Created By must be a positive number.');
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
       // Images must exist as bytes before upload, not merely as filenames.
       final filesByName = <String>{
         for (final file in selectedExcelImages)
           if (file.bytes != null) file.name.toLowerCase(),
       };
       final missingImages = <String>{};
       for (final row in excelDetails) {
         final serial = asInt(row['_excel_serial']) ?? 0;
         if (originalExcelPhotosBySerial[serial]?.isNotEmpty == true) {
           continue;
         }
         final names = row['_image_names'];
         if (names is List) {
           for (final name in names) {
             final filename = name.toString().trim();
             if (filename.isNotEmpty &&
                 !filesByName.contains(filename.toLowerCase())) {
               missingImages.add(filename);
             }
           }
         }
       }
       if (missingImages.isNotEmpty) {
         showError('Missing picture files: ${missingImages.join(', ')}');
         return;
       }
       final missing3DModels = _missingExcel3DModelFiles();

      if (missing3DModels.isNotEmpty) {
        showError(
          'Excel-এ 3D model filename আছে, কিন্তু file select করা হয়নি: '
              '${missing3DModels.join(', ')}',
        );
        return;
      }

      details = excelDetails.map((original) {
        final detail = Map<String, dynamic>.from(original);

        detail['images'] =
            _excelImagesPayloadForDetail(detail);

        final model3DPayload =
        _excel3DModelPayloadForDetail(detail);

        if (model3DPayload != null) {
          detail['model_3d'] = model3DPayload;
        } else {
          detail.remove('model_3d');
        }

        detail.remove('_image_names');
        detail.remove('_model_3d_name');

        return detail;
      }).toList();
      for (var index = 0; index < details.length; index++) {
        final images = details[index]['images'];
        if (images is! List || images.isEmpty) {
          showError('Excel serial ${index + 1}: picture required. '
              'Select Original Photos for this product or embed a picture in Excel.');
          return;
        }
      }
    } else {
       if (selectedImages.isEmpty) {
         showError('Picture is mandatory');
         return;
       }
       if (validateSizeRange(sizeRangeController.text) != null ||
            double.tryParse(moqController.text.trim()) == null ||
           double.tryParse(moqController.text.trim())! <= 0 ||
           double.tryParse(fobController.text.trim()) == null ||
           double.tryParse(fobController.text.trim())! < 0) {
          showError(
            validateSizeRange(sizeRangeController.text) ??
            'MOQ (> 0) and valid FOB are mandatory',
          );
         return;
       }
       details = [createManualDetail()];
     }

    // Validate the final detail payload too. This prevents an empty
    // size_range from being posted when users edit manual/Excel values.
    for (var index = 0; index < details.length; index++) {
      final raw = details[index];
      final String sizeRange = asText(
        raw['size_range'] ?? raw['sizeRange'] ?? raw['SIZE RANGE'],
      ).trim();
       final issue = validateSizeRange(sizeRange);
       if (issue != null) {
         showError('Row ${index + 1}: $issue');
         return;
       }
    }

    // Final normalization before JSON encode / HTTP POST.
    // This guarantees CBM and SIZE_RANGE are always JSON strings.
    final DateTime uploadTime = DateTime.now();
    late final List<Map<String, dynamic>> normalizedDetails;
    try {
      normalizedDetails = <Map<String, dynamic>>[
        for (var index = 0; index < details.length; index++)
          _normalizeDetailForApi(<String, dynamic>{
            ...details[index],
            // Excel: use its automatic SERIAL. Manual entry: serial 1.
            // Never send internal _excel_serial to the Oracle API.
            'images': assignAutomaticImageFileNames(
              images: details[index]['images'] is List
                  ? details[index]['images'] as List
                  : <dynamic>[],
              itemCode: asText(details[index]['item_code']),
              itemName: asText(details[index]['description']),
              excelSerial: asInt(details[index]['_excel_serial']) ?? index + 1,
              uploadTime: uploadTime,
            ),
          }),
      ];
    } on FormatException catch (error) {
      showError('Picture file naming failed: ${error.message}');
      return;
    }

    final Map<String, dynamic> body = {
      "business":
      businessController.text.trim(),

      "sub_category":
      subCategoryController.text.trim(),

      // Leave the optional master field out of JSON when not provided.
      if (organizationId != null)
        "organization_id": organizationId,


      "display_room_name":
      displayRoomNameController.text.trim(),

      "created_by":
      createdBy,

      "status":
      statusController.text.trim(),

      if (assignee != null)
        "assignee": assignee,

      "details":
      normalizedDetails,
    };

    final int totalImageCount = normalizedDetails.fold<int>(
      0,
          (sum, detail) =>
      sum + ((detail['images'] is List) ? (detail['images'] as List).length : 0),
    );

    final int total3DModelCount = normalizedDetails.fold<int>(
      0,
          (sum, detail) =>
      sum + (detail['model_3d'] is Map ? 1 : 0),
    );

    debugPrint('==========================================');
    debugPrint('POST DISPLAY ROOM ITEM UPLOAD');
    debugPrint('URL => $apiUrl');
    debugPrint('DETAIL COUNT => ${details.length}');
    debugPrint('IMAGE COUNT => $totalImageCount');
    debugPrint('3D MODEL COUNT => $total3DModelCount');
    debugPrint(
      'PAYLOAD => ${jsonEncode(_debugSafeBody(body))}',
    );
    debugPrint('==========================================');

    // Validate original pixel dimensions before the HTTP request.
    // This never compresses/resizes the image or changes auto-generated names.
    if (!await _confirmImageQualityBeforeUpload()) return;
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await DisplayRoomApiService.uploadItem(body);

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

      final String message = json is Map
          ? (json['message'] ?? json['MESSAGE'] ?? '').toString()
          : response.body;
      final bool success = _isConfirmedApiSuccess(response, json);

      if (!mounted) {
        return;
      }

      if (success) {
        final bool wasExcelUpload = excelDetails.isNotEmpty;
        final int uploadedCount = normalizedDetails.length;
        final notice = wasExcelUpload
            ? 'Excel Uploaded Successfully ($uploadedCount items)'
            : 'Submitted Successfully';

        _clearEntryAfterSuccess(notice: notice);
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF15803D),
          duration: const Duration(seconds: 7),
          content: Text(notice),
        ));
        // Acknowledgement dialog stays on screen until explicitly closed.
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF15803D)),
                SizedBox(width: 10),
                Expanded(child: Text('Submitted Successfully')),
              ],
            ),
            content: Text(wasExcelUpload
                ? '$uploadedCount Excel items uploaded successfully.\nThe entry page is now cleared.'
                : 'Product uploaded successfully.\nThe entry page is now cleared.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        final step =
        json is Map ? json['step']?.toString() : null;

        final errorCode =
        json is Map ? json['error_code']?.toString() : null;

        final itemCode =
        json is Map ? json['item_code']?.toString() : null;

        final List<String> parts = [
          message,
          if (step != null && step.isNotEmpty) 'Step: $step',
          if (itemCode != null && itemCode.isNotEmpty)
            'Item: $itemCode',
          if (errorCode != null && errorCode.isNotEmpty)
            'Code: $errorCode',
        ];

        showError(parts.join('\n'));
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

  // Visible even when the submit button is far below the invalid field.
  void showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
        content: Text('Validation failed. See the error details dialog.'),
      ),
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 10),
          Expanded(child: Text('Please fix these fields')),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
          child: SingleChildScrollView(
            child: SelectableText(message),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
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

            const SizedBox(height: 14),
            Text(
              'Original-resolution product photos (recommended)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Keep EVERY Excel column unchanged. Select the original JPG/PNG '
              'for each product below. Selected full-size image bytes override '
              'small Excel embedded thumbnails. No filename or new Excel '
              'column required. ITEM CODE is optional; photo filenames are generated automatically on submit.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: excelDetails.length * 110.0 > 350.0
                  ? 350.0
                  : excelDetails.length * 110.0,
              child: ListView.builder(
                itemCount: excelDetails.length,
                itemBuilder: (context, index) {
                  final row = excelDetails[index];
                  final serial = asInt(row['_excel_serial']) ?? index + 1;
                  final photos = originalExcelPhotosBySerial[serial] ??
                      const <PlatformFile>[];
                  final sizes = originalExcelPhotoDimensions[serial] ??
                      const <String>[];
                  final busy = readingOriginalPhotosForSerial == serial;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$serial. ${asText(row['item_code'])}  '
                                  '${asText(row['description'])}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  photos.isEmpty
                                      ? 'Excel picture (if any) will be used'
                                      : '${photos.length} original photo(s): '
                                          '${sizes.join(', ')}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: photos.isEmpty
                                        ? Colors.orange.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (photos.isNotEmpty)
                            IconButton(
                              onPressed: isLoading ||
                                      readingOriginalPhotosForSerial != null
                                  ? null
                                  : () => clearOriginalExcelPhotos(serial),
                              tooltip: 'Remove original image override',
                              icon: const Icon(Icons.clear),
                            ),
                          const SizedBox(width: 3),
                          OutlinedButton.icon(
                            onPressed: isLoading ||
                                    readingOriginalPhotosForSerial != null
                                ? null
                                : () => selectOriginalExcelPhotos(serial),
                            icon: busy
                                ? const SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_library_outlined),
                            label: Text(photos.isEmpty ? 'Select' : 'Replace'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

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
                    : 'Select Images (Legacy Excel Only)',
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'PICTURE cell-এ ছবি paste করুন; filename লিখতে হবে না। '
                  'Upload করার সময় Item Code + Item Name + Serial + Image Number + Date + Time অনুযায়ী filename তৈরি হবে। '
                  'পুরোনো filename-based Excel-ও support করবে।',
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

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: isReadingExcel3DModels || isLoading
                  ? null
                  : selectExcel3DModels,
              icon: isReadingExcel3DModels
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.view_in_ar_outlined),
              label: Text(
                isReadingExcel3DModels
                    ? 'Reading 3D Models...'
                    : 'Select Excel 3D Model Files (.glb)',
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Optional: Excel-এ "3D MODEL" column-এ .glb filename দিন। '
                  'প্রতি item-এ সর্বোচ্চ 1টি model match হবে.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            if (selectedExcel3DModels.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...selectedExcel3DModels.map(
                        (file) => Chip(
                      avatar: const Icon(Icons.view_in_ar_outlined, size: 18),
                      label: Text(file.name),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear 3D Models'),
                    onPressed: isLoading ? null : clearExcel3DModels,
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
  // MANUAL 3D MODEL PICKER UI
  // ============================================================

  Widget buildManual3DModelPicker() {
    final file = selected3DModel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.view_in_ar_outlined),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '3D Model (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'শুধু .GLB format — একটি item-এ সর্বোচ্চ 1টি 3D model.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isReading3DModel || isLoading
                ? null
                : selectManual3DModel,
            icon: isReading3DModel
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.upload_file_outlined),
            label: Text(
              isReading3DModel
                  ? 'Reading 3D Model...'
                  : file == null
                  ? 'Select 3D Model (.glb)'
                  : 'Change 3D Model',
            ),
          ),
          if (file != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blueGrey.shade100,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.view_in_ar_outlined,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatFileSize(file.size)} • model/gltf-binary',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove 3D model',
                    onPressed: isLoading
                        ? null
                        : removeManual3DModel,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
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
                if (_submissionNotice != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: Color(0xFF15803D)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_submissionNotice!,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: () => setState(() => _submissionNotice = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                // ==================================================
                // EXCEL = OPTIONAL ONLY
                // ==================================================

                buildExcelOption(),

                if (excelTableRows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ExcelDataTablePreview(
                    headers: excelTableHeaders,
                    rows: excelTableRows,
                  ),
                ],

                const SizedBox(height: 25),

                // ==================================================
                // MASTER INFORMATION
                // ==================================================

                sectionTitle(
                  'Master Information',
                  Icons.meeting_room_outlined,
                ),

                twoFields(
                  first: _buildFixedDropdown(
                    label: 'Category',
                    controller: businessController,
                    choices: _categoryOptions,
                  ),
                  second: twoFields(
                    first: _buildFixedDropdown(
                      label: 'Sub Category',
                      controller: subCategoryController,
                      choices: _subCategoryOptions,
                      isRequired: false,
                    ),
                    second: DropdownButtonFormField<String>(
                      value: statusController.text.isEmpty
                          ? 'ACTIVE'
                          : statusController.text,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ACTIVE',
                          child: Text('ACTIVE'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVE',
                          child: Text('INACTIVE'),
                        ),
                      ],
                      onChanged: isLoading
                          ? null
                          : (value) {
                        if (value != null) {
                          setState(() {
                            statusController.text = value;
                          });
                        }
                      },
                    ),
                  ),
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'Organization ID (Optional)',
                    hint: 'Optional, e.g. 3941',
                    controller: organizationIdController,
                    keyboardType: TextInputType.number,
                    required: false,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return excelDetails.isNotEmpty
                            ? 'Organization ID is required for Excel upload'
                            : null;
                      }
                      final id = int.tryParse(text);
                      if (id == null || id <= 0) {
                        return 'Enter a valid numeric Organization ID';
                      }
                      return null;
                    },
                  ),
                  second: buildTextField(
                    label: 'Staff ID (Created By)',
                    hint: 'Required: e.g. 506618',
                    controller:
                    createdByController,
                    keyboardType:
                    TextInputType.number,
                    validator: (value) {
                      final staffId = int.tryParse((value ?? '').trim());
                      if (staffId == null || staffId <= 0) {
                        return 'Staff ID is required (positive numeric ID)';
                      }
                      return null;
                    },
                  ),
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'Display Room Name',
                    hint: 'e.g. MLIL-R10-Ftwr-Display Room',
                    controller: displayRoomNameController,
                    required: false,
                  ),
                  second: buildTextField(
                    label: 'Assignee',
                    hint: 'Optional',
                    controller: assigneeController,
                    keyboardType: TextInputType.number,
                    required: false,
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
                    label: 'Item Category',
                    hint: 'e.g. Cemented',
                    controller: productCategoryController,
                  ),
                  second: buildTextField(
                    label: 'CBM',
                    hint: 'e.g. 54 CBM / Small / N/A / 12 x 20',
                    controller: cbmController,
                    required: false,
                    keyboardType: TextInputType.text,
                  ),
                ),

                gap(),

                Row(
                  children: [
                    Expanded(
                      child: buildTextField(
                        label: 'Item Code (Optional)',
                        hint: 'Optional — leave empty if product has no code',
                        controller: itemCodeController,
                        required: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildTextField(
                        label: 'Sub Inventory Code',
                        hint: 'e.g. PN1.RM',
                        controller: subInventoryCodeController,
                    required: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildTextField(
                        label: 'Weight (g)',
                        hint: 'In grams, e.g. 130',
                        controller: weightController,
                        required: false,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          final grams = double.tryParse(text);
                          if (grams == null || grams < 0 || !grams.isFinite) {
                            return 'Enter a non-negative weight in grams (g)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                gap(),

                buildTextField(
                  label: 'Description / Item Name',
                  hint: 'Required if Item Code is empty',
                  controller: descriptionController,
                    required: false,
                  validator: (value) {
                    if (itemCodeController.text.trim().isEmpty &&
                        (value ?? '').trim().isEmpty) {
                      return 'Item Name is required when Item Code is empty';
                    }
                    return null;
                  },
                  maxLines: 2,
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'UOM',
                    hint: 'e.g. Pair',
                    controller: uomController,
                    required: false,
                  ),
                  second: buildTextField(
                    label: 'FOB',
                    hint: 'e.g. 4.35',
                    controller: fobController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),

                gap(),

                buildTextField(
                  label: 'Material Specification',
                  hint: 'e.g. Mesh+3mm Foam+42gtc lamination',
                  controller: materialSpecificationController,
                    required: false,
                  maxLines: 2,
                ),

                gap(),

                 twoFields(
                   first: buildTextField(
                     label: 'Size Range',
                      hint: 'e.g. 36-42',
                     controller: sizeRangeController,
                      validator: (value) => validateSizeRange(value),
                   ),
                   second: buildTextField(
                     label: 'MOQ',
                     hint: 'e.g. 250',
                     controller: moqController,
                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
                   ),
                 ),

                 gap(),

                 if (excelDetails.isEmpty) ...[
                  buildManualImagePicker(),
                  gap(),
                  buildManual3DModelPicker(),
                  gap(),
                ],

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
    displayRoomNameController.dispose();
    createdByController.dispose();
    statusController.dispose();
    assigneeController.dispose();

    productCategoryController.dispose();
    itemCodeController.dispose();
    descriptionController.dispose();
    uomController.dispose();
    subInventoryCodeController.dispose();
    cbmController.dispose();
    fobController.dispose();
    materialSpecificationController.dispose();
    weightController.dispose();
     sizeRangeController.dispose();
     moqController.dispose();

    super.dispose();
  }
}

