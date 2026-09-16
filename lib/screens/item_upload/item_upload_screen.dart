//
//
//
// import 'dart:convert';
//
// import 'package:excel/excel.dart' as xls;
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
//
// import '../../core/constants/api_constants.dart';
// import '../../services/display_room_api_service.dart';
// import '../../utils/excel_value_utils.dart';
// import '../../widgets/common_form_widgets.dart';
// import '../../widgets/excel_data_table_preview.dart';
//
// class ItemUploadScreen extends StatefulWidget {
//   const ItemUploadScreen({super.key});
//
//   @override
//   State<ItemUploadScreen> createState() =>
//       _ItemUploadScreenState();
// }
//
// class _ItemUploadScreenState extends State<ItemUploadScreen> {
//   static const String apiUrl = ApiConstants.uploadItem;
//
//   final _formKey = GlobalKey<FormState>();
//
//   bool isLoading = false;
//   bool isReadingExcel = false;
//
//   String? selectedExcelName;
//
//   /// Excel select করলে API payload-এর জন্য mapped detail এখানে থাকবে।
//   List<Map<String, dynamic>> excelDetails = [];
//
//   /// Excel-এর raw normalized headers এবং rows DataTable preview-এর জন্য।
//   List<String> excelTableHeaders = [];
//   List<Map<String, dynamic>> excelTableRows = [];
//
//
//   // ============================================================
//   // IMAGE STATE
//   // ============================================================
//
//   /// Manual item-এর জন্য সর্বোচ্চ 5টি image।
//   final List<PlatformFile> selectedImages = [];
//
//   /// Excel mode-এ IMAGE column-এর filename-এর সাথে match করার জন্য
//   /// একসাথে অনেক image file select করা যাবে। Backend limit প্রতি item-এ 5।
//   final List<PlatformFile> selectedExcelImages = [];
//
//   bool isReadingImages = false;
//   bool isReadingExcelImages = false;
//
//   // ============================================================
//   // 3D MODEL STATE
//   // ============================================================
//
//   /// Manual mode-এ প্রতি item-এর জন্য optional 1টি .glb model।
//   PlatformFile? selected3DModel;
//
//   /// Excel mode-এ প্রতিটি row-এর 3D MODEL filename-এর সাথে match করবে।
//   final List<PlatformFile> selectedExcel3DModels = [];
//
//   bool isReading3DModel = false;
//   bool isReadingExcel3DModels = false;
//
//   // ============================================================
//   // MASTER CONTROLLERS
//   // ============================================================
//
//   final businessController = TextEditingController();
//   final subCategoryController = TextEditingController();
//   final organizationIdController = TextEditingController();
//   final displayRoomNoController = TextEditingController();
//   final displayRoomNameController = TextEditingController();
//   final createdByController = TextEditingController();
//   final statusController = TextEditingController();
//   final assigneeController = TextEditingController();
//
//   // ============================================================
//   // DETAIL CONTROLLERS
//   // ============================================================
//
//   final sourceSlController = TextEditingController();
//   final productCategoryController = TextEditingController();
//   final printController = TextEditingController();
//   final itemQrCodeController = TextEditingController();
//
//   final fileUrlController = TextEditingController();
//   final fileNameController = TextEditingController();
//   final mimeTypeController = TextEditingController();
//
//   final itemCodeController = TextEditingController();
//   final descriptionController = TextEditingController();
//   final uomController = TextEditingController();
//
//   final quantityController = TextEditingController();
//   final unitPriceController = TextEditingController();
//
//   final subInventoryCodeController = TextEditingController();
//   final locatorIdController = TextEditingController();
//
//   final cbmController = TextEditingController();
//   final fobController = TextEditingController();
//
//   final materialSpecificationController =
//   TextEditingController();
//
//   final weightController = TextEditingController();
//
//   // ============================================================
//   // EXCEL HELPERS
//   // ============================================================
//
//
//
//
//
//
//
//   // ============================================================
//   // IMAGE HELPERS
//   // ============================================================
//
//
//
//   List<Map<String, dynamic>> _manualImagesPayload() {
//     return selectedImages
//         .where((file) => file.bytes != null)
//         .map(platformFileToImageJson)
//         .toList();
//   }
//
//   List<Map<String, dynamic>> _excelImagesPayloadForDetail(
//       Map<String, dynamic> detail,
//       ) {
//     final rawNames = detail['_image_names'];
//
//     final List<String> expectedNames = rawNames is List
//         ? rawNames.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
//         : imageNamesFromExcelValue(detail['file_name']);
//
//     if (expectedNames.isEmpty) {
//       return <Map<String, dynamic>>[];
//     }
//
//     final lowerNames = expectedNames.map((e) => e.toLowerCase()).toSet();
//
//     return selectedExcelImages
//         .where(
//           (file) =>
//       file.bytes != null && lowerNames.contains(file.name.toLowerCase()),
//     )
//         .take(5)
//         .map(platformFileToImageJson)
//         .toList();
//   }
//
//   // ============================================================
//   // 3D MODEL HELPERS
//   // ============================================================
//
//   Map<String, dynamic>? _platformFileTo3DModelJson(PlatformFile? file) {
//     if (file == null || file.bytes == null) {
//       return null;
//     }
//
//     return <String, dynamic>{
//       'file_base64': base64Encode(file.bytes!),
//       'file_name': file.name,
//       'mime_type': 'model/gltf-binary',
//     };
//   }
//
//   String _modelNameFromExcelRow(Map<String, dynamic> row) {
//     const possibleHeaders = <String>[
//       '3D MODEL',
//       '3D MODEL FILE',
//       'MODEL 3D',
//       'GLB',
//       'GLB FILE',
//     ];
//
//     for (final header in possibleHeaders) {
//       final value = asText(row[header]);
//       if (value.isNotEmpty) {
//         return value;
//       }
//     }
//
//     return '';
//   }
//
//   Map<String, dynamic>? _excel3DModelPayloadForDetail(
//       Map<String, dynamic> detail,
//       ) {
//     final expectedName =
//         detail['_model_3d_name']?.toString().trim() ?? '';
//
//     if (expectedName.isEmpty) {
//       return null;
//     }
//
//     PlatformFile? matchedFile;
//
//     for (final file in selectedExcel3DModels) {
//       if (file.name.toLowerCase() == expectedName.toLowerCase()) {
//         matchedFile = file;
//         break;
//       }
//     }
//
//     return _platformFileTo3DModelJson(matchedFile);
//   }
//
//   List<String> _missingExcel3DModelFiles() {
//     final expectedNames = excelDetails
//         .map(
//           (detail) =>
//       detail['_model_3d_name']?.toString().trim() ?? '',
//     )
//         .where((name) => name.isNotEmpty)
//         .toSet();
//
//     if (expectedNames.isEmpty) {
//       return <String>[];
//     }
//
//     final selectedNames = selectedExcel3DModels
//         .where((file) => file.bytes != null)
//         .map((file) => file.name.toLowerCase())
//         .toSet();
//
//     return expectedNames
//         .where((name) => !selectedNames.contains(name.toLowerCase()))
//         .toList();
//   }
//
//   Future<void> selectManual3DModel() async {
//     try {
//       setState(() {
//         isReading3DModel = true;
//       });
//
//       final result = await FilePicker.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: const ['glb'],
//         allowMultiple: false,
//         withData: true,
//       );
//
//       if (result == null) {
//         return;
//       }
//
//       final file = result.files.single;
//
//       if (file.bytes == null) {
//         showError('Selected .glb file read করা যাচ্ছে না।');
//         return;
//       }
//
//       if (!file.name.toLowerCase().endsWith('.glb')) {
//         showError('শুধু .glb 3D model select করা যাবে।');
//         return;
//       }
//
//       setState(() {
//         selected3DModel = file;
//       });
//     } catch (e) {
//       showError('3D model select failed: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           isReading3DModel = false;
//         });
//       }
//     }
//   }
//
//   Future<void> selectExcel3DModels() async {
//     try {
//       setState(() {
//         isReadingExcel3DModels = true;
//       });
//
//       final result = await FilePicker.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: const ['glb'],
//         allowMultiple: true,
//         withData: true,
//       );
//
//       if (result == null) {
//         return;
//       }
//
//       final validFiles = result.files
//           .where(
//             (file) =>
//         file.bytes != null &&
//             file.name.toLowerCase().endsWith('.glb'),
//       )
//           .toList();
//
//       if (validFiles.isEmpty) {
//         showError('Valid .glb file পাওয়া যায়নি।');
//         return;
//       }
//
//       final Map<String, PlatformFile> merged = {
//         for (final file in selectedExcel3DModels)
//           file.name.toLowerCase(): file,
//         for (final file in validFiles)
//           file.name.toLowerCase(): file,
//       };
//
//       setState(() {
//         selectedExcel3DModels
//           ..clear()
//           ..addAll(merged.values);
//       });
//     } catch (e) {
//       showError('Excel 3D model select failed: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           isReadingExcel3DModels = false;
//         });
//       }
//     }
//   }
//
//   void removeManual3DModel() {
//     setState(() {
//       selected3DModel = null;
//     });
//   }
//
//   void clearExcel3DModels() {
//     setState(() {
//       selectedExcel3DModels.clear();
//     });
//   }
//
//   String _formatFileSize(int bytes) {
//     if (bytes < 1024) {
//       return '$bytes B';
//     }
//
//     final kb = bytes / 1024;
//     if (kb < 1024) {
//       return '${kb.toStringAsFixed(1)} KB';
//     }
//
//     final mb = kb / 1024;
//     return '${mb.toStringAsFixed(2)} MB';
//   }
//
//   Future<void> selectManualImages() async {
//     if (selectedImages.length >= 5) {
//       showError('একটি item-এর জন্য সর্বোচ্চ 5টি image select করা যাবে।');
//       return;
//     }
//
//     try {
//       setState(() {
//         isReadingImages = true;
//       });
//
//       final result = await FilePicker.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
//         allowMultiple: true,
//         withData: true,
//       );
//
//       if (result == null) {
//         return;
//       }
//
//       final remaining = 5 - selectedImages.length;
//       final validFiles = result.files
//           .where((file) => file.bytes != null)
//           .take(remaining)
//           .toList();
//
//       if (validFiles.isEmpty) {
//         showError('Selected image file read করা যাচ্ছে না।');
//         return;
//       }
//
//       setState(() {
//         selectedImages.addAll(validFiles);
//
//         final first = selectedImages.first;
//         fileNameController.text = first.name;
//         fileUrlController.text = first.name;
//         mimeTypeController.text = mimeTypeFromFileName(first.name);
//       });
//
//       if (result.files.length > remaining) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('সর্বোচ্চ 5টি image নেওয়া হয়েছে। অতিরিক্ত image বাদ দেওয়া হয়েছে।'),
//           ),
//         );
//       }
//     } catch (e) {
//       showError('Image select failed: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           isReadingImages = false;
//         });
//       }
//     }
//   }
//
//   Future<void> selectExcelImages() async {
//     try {
//       setState(() {
//         isReadingExcelImages = true;
//       });
//
//       final result = await FilePicker.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
//         allowMultiple: true,
//         withData: true,
//       );
//
//       if (result == null) {
//         return;
//       }
//
//       final validFiles = result.files.where((file) => file.bytes != null).toList();
//
//       if (validFiles.isEmpty) {
//         showError('Selected image files read করা যাচ্ছে না।');
//         return;
//       }
//
//       final Map<String, PlatformFile> merged = {
//         for (final file in selectedExcelImages) file.name.toLowerCase(): file,
//         for (final file in validFiles) file.name.toLowerCase(): file,
//       };
//
//       setState(() {
//         selectedExcelImages
//           ..clear()
//           ..addAll(merged.values);
//       });
//     } catch (e) {
//       showError('Excel image select failed: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           isReadingExcelImages = false;
//         });
//       }
//     }
//   }
//
//   void removeManualImage(int index) {
//     setState(() {
//       selectedImages.removeAt(index);
//
//       if (selectedImages.isEmpty) {
//         fileNameController.clear();
//         fileUrlController.clear();
//         mimeTypeController.clear();
//       } else {
//         final first = selectedImages.first;
//         fileNameController.text = first.name;
//         fileUrlController.text = first.name;
//         mimeTypeController.text = mimeTypeFromFileName(first.name);
//       }
//     });
//   }
//
//   void clearExcelImages() {
//     setState(() {
//       selectedExcelImages.clear();
//     });
//   }
//
//   // ============================================================
//   // SELECT EXCEL
//   // ============================================================
//
//   Future<void> selectExcelFile() async {
//     try {
//       setState(() {
//         isReadingExcel = true;
//       });
//
//       final result = await FilePicker.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['xlsx'],
//         allowMultiple: false,
//         withData: true,
//       );
//
//       if (result == null) {
//         return;
//       }
//
//       final file = result.files.single;
//
//       if (file.bytes == null) {
//         throw Exception(
//           'Excel file read করা যাচ্ছে না',
//         );
//       }
//
//       final excel =
//       xls.Excel.decodeBytes(file.bytes!);
//
//       if (excel.tables.isEmpty) {
//         throw Exception(
//           'Excel file-এ কোনো sheet পাওয়া যায়নি',
//         );
//       }
//
//       final sheetName = excel.tables.keys.first;
//       final sheet = excel.tables[sheetName];
//
//       if (sheet == null || sheet.rows.isEmpty) {
//         throw Exception(
//           'Excel sheet empty',
//         );
//       }
//
//       // ========================================================
//       // READ HEADERS
//       // ========================================================
//
//       final headerRow = sheet.rows.first;
//
//       final List<String> headers = [];
//
//       for (final cell in headerRow) {
//         headers.add(
//           normalizeHeader(
//             asText(
//               getExcelValue(cell),
//             ),
//           ),
//         );
//       }
//
//       debugPrint('Excel Headers: $headers');
//
//       // ========================================================
//       // READ ROWS
//       // ========================================================
//
//       final List<Map<String, dynamic>> rows = [];
//
//       for (
//       int rowIndex = 1;
//       rowIndex < sheet.rows.length;
//       rowIndex++
//       ) {
//         final excelRow = sheet.rows[rowIndex];
//
//         final Map<String, dynamic> row = {};
//
//         for (
//         int columnIndex = 0;
//         columnIndex < headers.length;
//         columnIndex++
//         ) {
//           final header = headers[columnIndex];
//
//           if (header.isEmpty) {
//             continue;
//           }
//
//           dynamic value;
//
//           if (columnIndex < excelRow.length) {
//             value = getExcelValue(
//               excelRow[columnIndex],
//             );
//           }
//
//           row[header] = value;
//         }
//
//         final itemCode =
//         asText(row['ITEM CODE']);
//
//         // Completely empty row skip
//         if (itemCode.isEmpty) {
//           continue;
//         }
//
//         rows.add(row);
//       }
//
//       if (rows.isEmpty) {
//         throw Exception(
//           'Excel file-এ valid item পাওয়া যায়নি',
//         );
//       }
//
//       // ========================================================
//       // FIRST ROW -> MASTER + MANUAL FIELD PREVIEW
//       // ========================================================
//
//       final firstRow = rows.first;
//
//       setControllerIfAvailable(
//         businessController,
//         firstRow['BUSINESS'],
//       );
//
//       setControllerIfAvailable(
//         subCategoryController,
//         firstRow['SUB CATEGORY'],
//       );
//
//       setControllerIfAvailable(
//         displayRoomNoController,
//         firstRow['DISPLAY ROOM NO'],
//       );
//
//       setControllerIfAvailable(
//         displayRoomNameController,
//         firstRow['DISPLAY ROOM NAME'],
//       );
//
//       // Excel-এ Organization ID থাকলে fill করবে।
//       setControllerIfAvailable(
//         organizationIdController,
//         firstRow['ORGANIZATION ID'],
//       );
//
//       // First detail row preview
//       setControllerIfAvailable(
//         sourceSlController,
//         firstRow['SL'],
//       );
//
//       setControllerIfAvailable(
//         productCategoryController,
//         firstRow['PRODUCT CATEGORY'],
//       );
//
//       setControllerIfAvailable(
//         printController,
//         firstRow['PRINT'],
//       );
//
//       setControllerIfAvailable(
//         itemQrCodeController,
//         firstRow['ITEM QRCODE'],
//       );
//
//       setControllerIfAvailable(
//         itemCodeController,
//         firstRow['ITEM CODE'],
//       );
//
//       setControllerIfAvailable(
//         descriptionController,
//         firstRow['ITEM NAME'],
//       );
//
//       setControllerIfAvailable(
//         uomController,
//         firstRow['UOM'],
//       );
//
//       setControllerIfAvailable(
//         quantityController,
//         firstRow['QUANTITY'],
//       );
//
//       setControllerIfAvailable(
//         unitPriceController,
//         firstRow['UNIT PRICE'],
//       );
//
//       setControllerIfAvailable(
//         subInventoryCodeController,
//         firstRow['SUB INVENTORY CODE'],
//       );
//
//       setControllerIfAvailable(
//         locatorIdController,
//         firstRow['LOCATOR ID'],
//       );
//
//       setControllerIfAvailable(
//         cbmController,
//         firstRow['CBM'],
//       );
//
//       setControllerIfAvailable(
//         fobController,
//         firstRow['FOB'],
//       );
//
//       setControllerIfAvailable(
//         materialSpecificationController,
//         firstRow['MATERIAL SPECIFICATION'],
//       );
//
//       setControllerIfAvailable(
//         weightController,
//         firstRow['WEIGHT'],
//       );
//
//       final firstImageNames =
//       imageNamesFromExcelValue(firstRow['IMAGE']);
//
//       if (firstImageNames.isNotEmpty) {
//         final imageName = firstImageNames.first;
//         fileUrlController.text = imageName;
//         fileNameController.text = imageName;
//         mimeTypeController.text = mimeTypeFromFileName(imageName);
//       }
//
//       // ========================================================
//       // CREATE ALL EXCEL DETAILS
//       // ========================================================
//
//       final details = rows.map((row) {
//         final imageNames =
//         imageNamesFromExcelValue(row['IMAGE']);
//
//         final model3DName =
//         _modelNameFromExcelRow(row);
//
//         if (imageNames.length > 5) {
//           throw Exception(
//             'Item ${asText(row['ITEM CODE'])}: প্রতি item-এ সর্বোচ্চ 5টি image allowed.',
//           );
//         }
//
//         final firstImageName =
//         imageNames.isNotEmpty ? imageNames.first : '';
//
//         return <String, dynamic>{
//           "source_sl":
//           asInt(row['SL']),
//
//           "product_category":
//           asText(
//             row['PRODUCT CATEGORY'],
//           ),
//
//           "print":
//           asText(row['PRINT']),
//
//           "item_qrcode":
//           asText(
//             row['ITEM QRCODE'],
//           ),
//
//           "file_url":
//           firstImageName,
//
//           "file_name":
//           firstImageName,
//
//           "mime_type":
//           firstImageName.isEmpty
//               ? ''
//               : mimeTypeFromFileName(firstImageName),
//
//           // Internal helper. API পাঠানোর আগে remove করা হবে।
//           "_image_names":
//           imageNames,
//
//           // Excel-এর 3D MODEL / GLB filename.
//           // API পাঠানোর আগে actual Base64 payload দিয়ে replace হবে।
//           "_model_3d_name":
//           model3DName,
//
//           "item_code":
//           asText(
//             row['ITEM CODE'],
//           ),
//
//           "description":
//           asText(
//             row['ITEM NAME'],
//           ),
//
//           "uom":
//           asText(row['UOM']),
//
//           "quantity":
//           asDouble(
//             row['QUANTITY'],
//           ),
//
//           "unit_price":
//           asDouble(
//             row['UNIT PRICE'],
//           ),
//
//           "sub_inventory_code":
//           asText(
//             row['SUB INVENTORY CODE'],
//           ),
//
//           "locator_id":
//           asInt(
//             row['LOCATOR ID'],
//           ),
//
//           "cbm":
//           asText(row['CBM']),
//
//           "fob":
//           asDouble(row['FOB']),
//
//           "material_specification":
//           asText(
//             row['MATERIAL SPECIFICATION'],
//           ),
//
//           "weight":
//           asDouble(
//             row['WEIGHT'],
//           ),
//         };
//       }).toList();
//
//       setState(() {
//         selectedExcelName = file.name;
//         excelDetails = details;
//         excelTableHeaders = headers.where((header) => header.isNotEmpty).toList();
//         excelTableRows = rows;
//       });
//
//       if (!mounted) {
//         return;
//       }
//
//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.green,
//           content: Text(
//             '${details.length} Excel rows loaded',
//           ),
//         ),
//       );
//     } catch (e) {
//       if (!mounted) {
//         return;
//       }
//
//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text(
//             e.toString(),
//           ),
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() {
//           isReadingExcel = false;
//         });
//       }
//     }
//   }
//
//   void setControllerIfAvailable(
//       TextEditingController controller,
//       dynamic value,
//       ) {
//     final text = asText(value);
//
//     if (text.isNotEmpty) {
//       controller.text = text;
//     }
//   }
//
//   // ============================================================
//   // REMOVE EXCEL
//   // ============================================================
//
//   void removeExcel() {
//     setState(() {
//       selectedExcelName = null;
//       excelDetails = [];
//       excelTableHeaders = [];
//       excelTableRows = [];
//       selectedExcelImages.clear();
//       selectedExcel3DModels.clear();
//     });
//
//     ScaffoldMessenger.of(context)
//         .showSnackBar(
//       const SnackBar(
//         content: Text(
//           'Excel removed. Manual mode active.',
//         ),
//       ),
//     );
//   }
//
//   // ============================================================
//   // MANUAL DETAIL
//   // ============================================================
//
//   Map<String, dynamic> createManualDetail() {
//     final PlatformFile? firstImage =
//     selectedImages.isNotEmpty ? selectedImages.first : null;
//
//     final model3DPayload =
//     _platformFileTo3DModelJson(selected3DModel);
//
//     return {
//       "source_sl": int.tryParse(
//         sourceSlController.text.trim(),
//       ),
//
//       "product_category":
//       productCategoryController.text.trim(),
//
//       "print":
//       printController.text.trim(),
//
//       "item_qrcode":
//       itemQrCodeController.text.trim(),
//
//       "file_url":
//       firstImage?.name ?? fileUrlController.text.trim(),
//
//       "file_name":
//       firstImage?.name ?? fileNameController.text.trim(),
//
//       "mime_type":
//       firstImage != null
//           ? mimeTypeFromFileName(firstImage.name)
//           : mimeTypeController.text.trim(),
//
//       "images":
//       _manualImagesPayload(),
//
//       if (model3DPayload != null)
//         "model_3d":
//         model3DPayload,
//
//       "item_code":
//       itemCodeController.text.trim(),
//
//       "description":
//       descriptionController.text.trim(),
//
//       "uom":
//       uomController.text.trim(),
//
//       "quantity": double.tryParse(
//         quantityController.text.trim(),
//       ),
//
//       "unit_price": double.tryParse(
//         unitPriceController.text.trim(),
//       ),
//
//       "sub_inventory_code":
//       subInventoryCodeController.text.trim(),
//
//       "locator_id": int.tryParse(
//         locatorIdController.text.trim(),
//       ),
//
//       "cbm":
//       cbmController.text.trim(),
//
//       "fob": double.tryParse(
//         fobController.text.trim(),
//       ),
//
//       "material_specification":
//       materialSpecificationController
//           .text
//           .trim(),
//
//       "weight": double.tryParse(
//         weightController.text.trim(),
//       ),
//     };
//   }
//
//   // ============================================================
//   // API SUBMIT
//   // ============================================================
//
//   Future<void> uploadItem() async {
//     FocusScope.of(context).unfocus();
//
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//
//     final organizationId = int.tryParse(
//       organizationIdController.text.trim(),
//     );
//
//     final createdBy = int.tryParse(
//       createdByController.text.trim(),
//     );
//
//     final assignee = int.tryParse(
//       assigneeController.text.trim(),
//     );
//
//     if (organizationId == null) {
//       showError(
//         'Valid Organization ID দিন',
//       );
//       return;
//     }
//
//     if (createdBy == null) {
//       showError(
//         'Valid Created By দিন',
//       );
//       return;
//     }
//
//     if (assignee == null) {
//       showError(
//         'Valid Assignee দিন',
//       );
//       return;
//     }
//
//     // ==========================================================
//     // IMPORTANT
//     //
//     // Excel selected থাকলে -> Excel details[]
//     // Excel না থাকলে -> Manual single detail
//     // ==========================================================
//
//     final List<Map<String, dynamic>> details;
//
//     if (excelDetails.isNotEmpty) {
//       final missing3DModels = _missingExcel3DModelFiles();
//
//       if (missing3DModels.isNotEmpty) {
//         showError(
//           'Excel-এ 3D model filename আছে, কিন্তু file select করা হয়নি: '
//               '${missing3DModels.join(', ')}',
//         );
//         return;
//       }
//
//       details = excelDetails.map((original) {
//         final detail = Map<String, dynamic>.from(original);
//
//         detail['images'] =
//             _excelImagesPayloadForDetail(detail);
//
//         final model3DPayload =
//         _excel3DModelPayloadForDetail(detail);
//
//         if (model3DPayload != null) {
//           detail['model_3d'] = model3DPayload;
//         } else {
//           detail.remove('model_3d');
//         }
//
//         detail.remove('_image_names');
//         detail.remove('_model_3d_name');
//
//         return detail;
//       }).toList();
//     } else {
//       details = [
//         createManualDetail(),
//       ];
//     }
//
//     final Map<String, dynamic> body = {
//       "business":
//       businessController.text.trim(),
//
//       "sub_category":
//       subCategoryController.text.trim(),
//
//       "organization_id":
//       organizationId,
//
//       "display_room_no":
//       displayRoomNoController.text.trim(),
//
//       "display_room_name":
//       displayRoomNameController.text.trim(),
//
//       "created_by":
//       createdBy,
//
//       "status":
//       statusController.text.trim(),
//
//       "assignee":
//       assignee,
//
//       "details":
//       details,
//     };
//
//     final int totalImageCount = details.fold<int>(
//       0,
//           (sum, detail) =>
//       sum + ((detail['images'] is List) ? (detail['images'] as List).length : 0),
//     );
//
//     final int total3DModelCount = details.fold<int>(
//       0,
//           (sum, detail) =>
//       sum + (detail['model_3d'] is Map ? 1 : 0),
//     );
//
//     debugPrint('==========================================');
//     debugPrint('POST DISPLAY ROOM ITEM UPLOAD');
//     debugPrint('URL => $apiUrl');
//     debugPrint('DETAIL COUNT => ${details.length}');
//     debugPrint('IMAGE COUNT => $totalImageCount');
//     debugPrint('3D MODEL COUNT => $total3DModelCount');
//     debugPrint('==========================================');
//
//     setState(() {
//       isLoading = true;
//     });
//
//     try {
//       final response = await DisplayRoomApiService.uploadItem(body);
//
//       debugPrint(
//         'HTTP: ${response.statusCode}',
//       );
//
//       debugPrint(
//         'Response: ${response.body}',
//       );
//
//       dynamic json;
//
//       try {
//         json = jsonDecode(
//           response.body,
//         );
//       } catch (_) {
//         json = null;
//       }
//
//       final apiStatus =
//       json is Map
//           ? json['status_code']
//           : null;
//
//       final message =
//       json is Map
//           ? json['message']
//           ?.toString() ??
//           'Request completed'
//           : response.body;
//
//       final success =
//           response.statusCode >= 200 &&
//               response.statusCode < 300 &&
//               (
//                   apiStatus == null ||
//                       apiStatus == 200 ||
//                       apiStatus.toString() ==
//                           '200'
//               );
//
//       if (!mounted) {
//         return;
//       }
//
//       if (success) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.green,
//             content: Text(
//               excelDetails.isNotEmpty
//                   ? '$message\n${excelDetails.length} items uploaded.'
//                   : message,
//             ),
//           ),
//         );
//       } else {
//         showError(message);
//       }
//     } catch (e) {
//       if (!mounted) {
//         return;
//       }
//
//       showError(
//         e.toString(),
//       );
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//     }
//   }
//
//   void showError(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         content: Text(message),
//       ),
//     );
//   }
//
//   // ============================================================
//   // EXCEL OPTION UI
//   // ============================================================
//
//   Widget buildExcelOption() {
//     return Container(
//       padding:
//       const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         border: Border.all(
//           color: Colors.grey.shade300,
//         ),
//         borderRadius:
//         BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment:
//         CrossAxisAlignment.stretch,
//         children: [
//           Row(
//             children: [
//               const Icon(
//                 Icons.table_view_outlined,
//               ),
//
//               const SizedBox(width: 8),
//
//               const Expanded(
//                 child: Text(
//                   'Excel Upload (Optional)',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight:
//                     FontWeight.w600,
//                   ),
//                 ),
//               ),
//
//               if (selectedExcelName != null)
//                 IconButton(
//                   onPressed:
//                   isLoading
//                       ? null
//                       : removeExcel,
//                   icon: const Icon(
//                     Icons.close,
//                   ),
//                 ),
//             ],
//           ),
//
//           const SizedBox(height: 5),
//
//           Text(
//             'Manual entry অথবা Excel — '
//                 'দুইভাবেই upload করতে পারবেন।',
//             style: TextStyle(
//               fontSize: 13,
//               color:
//               Colors.grey.shade600,
//             ),
//           ),
//
//           const SizedBox(height: 12),
//
//           OutlinedButton.icon(
//             onPressed:
//             isReadingExcel ||
//                 isLoading
//                 ? null
//                 : selectExcelFile,
//             icon: isReadingExcel
//                 ? const SizedBox(
//               width: 18,
//               height: 18,
//               child:
//               CircularProgressIndicator(
//                 strokeWidth: 2,
//               ),
//             )
//                 : const Icon(
//               Icons.upload_file,
//             ),
//             label: Text(
//               isReadingExcel
//                   ? 'Reading Excel...'
//                   : 'Select Excel File',
//             ),
//           ),
//
//           if (selectedExcelName != null) ...[
//             const SizedBox(height: 10),
//
//             Container(
//               padding:
//               const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color:
//                 Colors.green.shade50,
//                 borderRadius:
//                 BorderRadius.circular(
//                   8,
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(
//                     Icons.check_circle,
//                     color: Colors.green,
//                   ),
//
//                   const SizedBox(width: 8),
//
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment:
//                       CrossAxisAlignment
//                           .start,
//                       children: [
//                         Text(
//                           selectedExcelName!,
//                           style:
//                           const TextStyle(
//                             fontWeight:
//                             FontWeight.w600,
//                           ),
//                         ),
//
//                         Text(
//                           '${excelDetails.length} item(s) loaded',
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 12),
//
//             OutlinedButton.icon(
//               onPressed: isReadingExcelImages || isLoading
//                   ? null
//                   : selectExcelImages,
//               icon: isReadingExcelImages
//                   ? const SizedBox(
//                 width: 18,
//                 height: 18,
//                 child: CircularProgressIndicator(strokeWidth: 2),
//               )
//                   : const Icon(Icons.add_photo_alternate_outlined),
//               label: Text(
//                 isReadingExcelImages
//                     ? 'Reading Images...'
//                     : 'Select Excel Image Files',
//               ),
//             ),
//
//             const SizedBox(height: 8),
//
//             Text(
//               'Excel-এর IMAGE column-এর filename-এর সাথে selected image file match হবে. '
//                   'একটি cell-এ multiple image হলে comma/semicolon দিয়ে filename লিখতে পারবেন.',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//
//             if (selectedExcelImages.isNotEmpty) ...[
//               const SizedBox(height: 10),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: [
//                   ...selectedExcelImages.map(
//                         (file) => Chip(
//                       avatar: const Icon(Icons.image_outlined, size: 18),
//                       label: Text(file.name),
//                     ),
//                   ),
//                   ActionChip(
//                     avatar: const Icon(Icons.delete_outline, size: 18),
//                     label: const Text('Clear Images'),
//                     onPressed: isLoading ? null : clearExcelImages,
//                   ),
//                 ],
//               ),
//             ],
//
//             const SizedBox(height: 18),
//             const Divider(),
//             const SizedBox(height: 10),
//
//             OutlinedButton.icon(
//               onPressed: isReadingExcel3DModels || isLoading
//                   ? null
//                   : selectExcel3DModels,
//               icon: isReadingExcel3DModels
//                   ? const SizedBox(
//                 width: 18,
//                 height: 18,
//                 child: CircularProgressIndicator(strokeWidth: 2),
//               )
//                   : const Icon(Icons.view_in_ar_outlined),
//               label: Text(
//                 isReadingExcel3DModels
//                     ? 'Reading 3D Models...'
//                     : 'Select Excel 3D Model Files (.glb)',
//               ),
//             ),
//
//             const SizedBox(height: 8),
//
//             Text(
//               'Optional: Excel-এ "3D MODEL" column-এ .glb filename দিন। '
//                   'প্রতি item-এ সর্বোচ্চ 1টি model match হবে.',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//
//             if (selectedExcel3DModels.isNotEmpty) ...[
//               const SizedBox(height: 10),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: [
//                   ...selectedExcel3DModels.map(
//                         (file) => Chip(
//                       avatar: const Icon(Icons.view_in_ar_outlined, size: 18),
//                       label: Text(file.name),
//                     ),
//                   ),
//                   ActionChip(
//                     avatar: const Icon(Icons.delete_outline, size: 18),
//                     label: const Text('Clear 3D Models'),
//                     onPressed: isLoading ? null : clearExcel3DModels,
//                   ),
//                 ],
//               ),
//             ],
//           ],
//         ],
//       ),
//     );
//   }
//
//   // ============================================================
//   // MANUAL IMAGE PICKER UI
//   // ============================================================
//
//   Widget buildManualImagePicker() {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.photo_library_outlined),
//               const SizedBox(width: 8),
//               const Expanded(
//                 child: Text(
//                   'Product Images',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               Text(
//                 '${selectedImages.length}/5',
//                 style: const TextStyle(fontWeight: FontWeight.w600),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             'JPG, JPEG, PNG, WEBP বা GIF — একটি item-এ সর্বোচ্চ 5টি image.',
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey.shade600,
//             ),
//           ),
//           const SizedBox(height: 12),
//           OutlinedButton.icon(
//             onPressed: isReadingImages || isLoading || selectedImages.length >= 5
//                 ? null
//                 : selectManualImages,
//             icon: isReadingImages
//                 ? const SizedBox(
//               width: 18,
//               height: 18,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             )
//                 : const Icon(Icons.add_photo_alternate_outlined),
//             label: Text(
//               isReadingImages
//                   ? 'Reading Images...'
//                   : selectedImages.isEmpty
//                   ? 'Select Images'
//                   : 'Add More Images',
//             ),
//           ),
//           if (selectedImages.isNotEmpty) ...[
//             const SizedBox(height: 12),
//             Wrap(
//               spacing: 10,
//               runSpacing: 10,
//               children: List.generate(
//                 selectedImages.length,
//                     (index) {
//                   final file = selectedImages[index];
//                   return Stack(
//                     clipBehavior: Clip.none,
//                     children: [
//                       Container(
//                         width: 120,
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey.shade300),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: file.bytes != null
//                                   ? Image.memory(
//                                 file.bytes!,
//                                 width: 100,
//                                 height: 80,
//                                 fit: BoxFit.cover,
//                               )
//                                   : Container(
//                                 width: 100,
//                                 height: 80,
//                                 color: Colors.grey.shade100,
//                                 child: const Icon(Icons.image_not_supported_outlined),
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               file.name,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(fontSize: 11),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Positioned(
//                         right: -8,
//                         top: -8,
//                         child: Material(
//                           color: Colors.red,
//                           shape: const CircleBorder(),
//                           child: InkWell(
//                             customBorder: const CircleBorder(),
//                             onTap: isLoading ? null : () => removeManualImage(index),
//                             child: const Padding(
//                               padding: EdgeInsets.all(4),
//                               child: Icon(
//                                 Icons.close,
//                                 size: 15,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   // ============================================================
//   // MANUAL 3D MODEL PICKER UI
//   // ============================================================
//
//   Widget buildManual3DModelPicker() {
//     final file = selected3DModel;
//
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.view_in_ar_outlined),
//               SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   '3D Model (Optional)',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             'শুধু .GLB format — একটি item-এ সর্বোচ্চ 1টি 3D model.',
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey.shade600,
//             ),
//           ),
//           const SizedBox(height: 12),
//           OutlinedButton.icon(
//             onPressed: isReading3DModel || isLoading
//                 ? null
//                 : selectManual3DModel,
//             icon: isReading3DModel
//                 ? const SizedBox(
//               width: 18,
//               height: 18,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             )
//                 : const Icon(Icons.upload_file_outlined),
//             label: Text(
//               isReading3DModel
//                   ? 'Reading 3D Model...'
//                   : file == null
//                   ? 'Select 3D Model (.glb)'
//                   : 'Change 3D Model',
//             ),
//           ),
//           if (file != null) ...[
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.blueGrey.shade50,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(
//                   color: Colors.blueGrey.shade100,
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(
//                     Icons.view_in_ar_outlined,
//                     size: 30,
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           file.name,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         const SizedBox(height: 3),
//                         Text(
//                           '${_formatFileSize(file.size)} • model/gltf-binary',
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   IconButton(
//                     tooltip: 'Remove 3D model',
//                     onPressed: isLoading
//                         ? null
//                         : removeManual3DModel,
//                     icon: const Icon(
//                       Icons.close,
//                       color: Colors.redAccent,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   // ============================================================
//   // UI
//   // ============================================================
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Display Room Item Upload',
//         ),
//         centerTitle: true,
//         actions: [
//           IconButton(
//             tooltip: 'View Items',
//             onPressed: () {
//               Navigator.pushNamed(context, '/items');
//             },
//             icon: const Icon(Icons.list_alt_outlined),
//           ),
//           IconButton(
//             tooltip: 'Delete Items',
//             onPressed: () {
//               Navigator.pushNamed(context, '/delete');
//             },
//             icon: const Icon(
//               Icons.delete_outline_rounded,
//               color: Colors.redAccent,
//             ),
//           ),
//           const SizedBox(width: 8),
//         ],
//       ),
//       body: SafeArea(
//         child: Form(
//           key: _formKey,
//           child: SingleChildScrollView(
//             padding:
//             const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment:
//               CrossAxisAlignment.stretch,
//               children: [
//                 // ==================================================
//                 // EXCEL = OPTIONAL ONLY
//                 // ==================================================
//
//                 buildExcelOption(),
//
//                 if (excelTableRows.isNotEmpty) ...[
//                   const SizedBox(height: 16),
//                   ExcelDataTablePreview(
//                     headers: excelTableHeaders,
//                     rows: excelTableRows,
//                   ),
//                 ],
//
//                 const SizedBox(height: 25),
//
//                 // ==================================================
//                 // MASTER INFORMATION
//                 // ==================================================
//
//                 sectionTitle(
//                   'Master Information',
//                   Icons.meeting_room_outlined,
//                 ),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'Business',
//                     hint: 'e.g. Footwear',
//                     controller:
//                     businessController,
//                   ),
//                   second: buildTextField(
//                     label: 'Sub Category',
//                     hint: 'e.g. Export',
//                     controller:
//                     subCategoryController,
//                   ),
//                 ),
//
//                 gap(),
//
//                 twoFields(
//                   first: buildTextField(
//                     label:
//                     'Organization ID',
//                     hint: 'e.g. 3941',
//                     controller:
//                     organizationIdController,
//                     keyboardType:
//                     TextInputType.number,
//                   ),
//                   second: buildTextField(
//                     label: 'Created By',
//                     hint: 'e.g. 506618',
//                     controller:
//                     createdByController,
//                     keyboardType:
//                     TextInputType.number,
//                   ),
//                 ),
//
//                 gap(),
//
//                 buildTextField(
//                   label: 'Display Room No',
//                   hint:
//                   'e.g. MLIL-R10-Ftwr-Disply',
//                   controller:
//                   displayRoomNoController,
//                 ),
//
//                 gap(),
//
//                 buildTextField(
//                   label:
//                   'Display Room Name',
//                   hint:
//                   'e.g. MLIL-R10-Ftwr-Display Room',
//                   controller:
//                   displayRoomNameController,
//                 ),
//
//                 gap(),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'Status',
//                     hint: 'e.g. ACTIVE',
//                     controller:
//                     statusController,
//                   ),
//                   second: buildTextField(
//                     label: 'Assignee',
//                     hint: 'e.g. 506618',
//                     controller:
//                     assigneeController,
//                     keyboardType:
//                     TextInputType.number,
//                   ),
//                 ),
//
//                 const SizedBox(height: 25),
//                 const Divider(),
//                 const SizedBox(height: 8),
//
//                 // ==================================================
//                 // ITEM DETAILS
//                 // ==================================================
//
//                 sectionTitle(
//                   'Item Details',
//                   Icons.inventory_2_outlined,
//                 ),
//
//                 if (excelDetails.isNotEmpty)
//                   Padding(
//                     padding:
//                     const EdgeInsets.only(
//                       bottom: 14,
//                     ),
//                     child: Container(
//                       padding:
//                       const EdgeInsets.all(
//                         12,
//                       ),
//                       decoration:
//                       BoxDecoration(
//                         color: Colors
//                             .blue.shade50,
//                         borderRadius:
//                         BorderRadius
//                             .circular(8),
//                       ),
//                       child: Text(
//                         'Excel mode: নিচে first item preview '
//                             'দেখানো হচ্ছে। Submit করলে '
//                             '${excelDetails.length}টি item details[]-এ যাবে।',
//                       ),
//                     ),
//                   ),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'Source SL',
//                     hint: 'e.g. 401',
//                     controller:
//                     sourceSlController,
//                     keyboardType:
//                     TextInputType.number,
//                   ),
//                   second: buildTextField(
//                     label:
//                     'Product Category',
//                     hint: 'e.g. Cemented',
//                     controller:
//                     productCategoryController,
//                   ),
//                 ),
//
//                 gap(),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'Print',
//                     hint:
//                     'e.g. 0100247925',
//                     controller:
//                     printController,
//                   ),
//                   second: buildTextField(
//                     label:
//                     'Item QR Code',
//                     hint:
//                     'e.g. 0100247925',
//                     controller:
//                     itemQrCodeController,
//                   ),
//                 ),
//
//                 gap(),
//
//                 buildTextField(
//                   label: 'Item Code',
//                   hint:
//                   'e.g. 0100247925',
//                   controller:
//                   itemCodeController,
//                 ),
//
//                 gap(),
//
//                 buildTextField(
//                   label: 'Description',
//                   hint:
//                   'e.g. LIDL SEMI FINISHED UPPER WHITE',
//                   controller:
//                   descriptionController,
//                   maxLines: 2,
//                 ),
//
//                 gap(),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'UOM',
//                     hint: 'e.g. Pair',
//                     controller:
//                     uomController,
//                   ),
//                   second: buildTextField(
//                     label: 'Quantity',
//                     hint: 'e.g. 1236',
//                     controller:
//                     quantityController,
//                     keyboardType:
//                     const TextInputType
//                         .numberWithOptions(
//                       decimal: true,
//                     ),
//                   ),
//                 ),
//
//                 gap(),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'Unit Price',
//                     hint: 'e.g. 1.26',
//                     controller:
//                     unitPriceController,
//                     keyboardType:
//                     const TextInputType
//                         .numberWithOptions(
//                       decimal: true,
//                     ),
//                   ),
//                   second: buildTextField(
//                     label: 'FOB',
//                     hint: 'e.g. 4.35',
//                     controller:
//                     fobController,
//                     keyboardType:
//                     const TextInputType
//                         .numberWithOptions(
//                       decimal: true,
//                     ),
//                   ),
//                 ),
//
//                 gap(),
//
//                 buildTextField(
//                   label:
//                   'Sub Inventory Code',
//                   hint: 'e.g. PN1.RM',
//                   controller:
//                   subInventoryCodeController,
//                 ),
//
//                 gap(),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'Locator ID',
//                     hint: 'e.g. 19680',
//                     controller:
//                     locatorIdController,
//                     keyboardType:
//                     TextInputType.number,
//                   ),
//                   second: buildTextField(
//                     label: 'CBM',
//                     hint: 'e.g. 54',
//                     controller:
//                     cbmController,
//                     keyboardType:
//                     const TextInputType
//                         .numberWithOptions(
//                       decimal: true,
//                     ),
//                   ),
//                 ),
//
//                 gap(),
//
//                 buildTextField(
//                   label:
//                   'Material Specification',
//                   hint:
//                   'e.g. Mesh+3mm Foam+42gtc lamination',
//                   controller:
//                   materialSpecificationController,
//                   maxLines: 2,
//                 ),
//
//                 gap(),
//
//                 if (excelDetails.isEmpty) ...[
//                   buildManualImagePicker(),
//                   gap(),
//                   buildManual3DModelPicker(),
//                   gap(),
//                 ],
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'Weight',
//                     hint: 'e.g. 0.2',
//                     controller:
//                     weightController,
//                     keyboardType:
//                     const TextInputType
//                         .numberWithOptions(
//                       decimal: true,
//                     ),
//                   ),
//                   second: buildTextField(
//                     label: 'MIME Type',
//                     hint: 'Auto from selected image',
//                     controller:
//                     mimeTypeController,
//                     required: false,
//                   ),
//                 ),
//
//                 gap(),
//
//                 twoFields(
//                   first: buildTextField(
//                     label: 'File Name',
//                     hint:
//                     'Auto from selected image',
//                     controller:
//                     fileNameController,
//                     required: false,
//                   ),
//                   second: buildTextField(
//                     label: 'File URL',
//                     hint:
//                     'Auto from selected image',
//                     controller:
//                     fileUrlController,
//                     required: false,
//                   ),
//                 ),
//
//                 const SizedBox(height: 30),
//
//                 // ==================================================
//                 // SUBMIT
//                 // ==================================================
//
//                 SizedBox(
//                   height: 55,
//                   child: FilledButton.icon(
//                     onPressed:
//                     isLoading
//                         ? null
//                         : uploadItem,
//                     icon: isLoading
//                         ? const SizedBox(
//                       width: 20,
//                       height: 20,
//                       child:
//                       CircularProgressIndicator(
//                         strokeWidth: 2,
//                       ),
//                     )
//                         : const Icon(
//                       Icons.cloud_upload,
//                     ),
//                     label: Text(
//                       isLoading
//                           ? 'Uploading...'
//                           : excelDetails.isNotEmpty
//                           ? 'Upload ${excelDetails.length} Excel Items'
//                           : 'Submit Item',
//                       style:
//                       const TextStyle(
//                         fontSize: 16,
//                         fontWeight:
//                         FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(height: 30),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ============================================================
//   // DISPOSE
//   // ============================================================
//
//   @override
//   void dispose() {
//     businessController.dispose();
//     subCategoryController.dispose();
//     organizationIdController.dispose();
//     displayRoomNoController.dispose();
//     displayRoomNameController.dispose();
//     createdByController.dispose();
//     statusController.dispose();
//     assigneeController.dispose();
//
//     sourceSlController.dispose();
//     productCategoryController.dispose();
//     printController.dispose();
//     itemQrCodeController.dispose();
//     fileUrlController.dispose();
//     fileNameController.dispose();
//     mimeTypeController.dispose();
//     itemCodeController.dispose();
//     descriptionController.dispose();
//     uomController.dispose();
//     quantityController.dispose();
//     unitPriceController.dispose();
//     subInventoryCodeController.dispose();
//     locatorIdController.dispose();
//     cbmController.dispose();
//     fobController.dispose();
//     materialSpecificationController.dispose();
//     weightController.dispose();
//
//     super.dispose();
//   }
// }





import 'dart:convert';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../services/display_room_api_service.dart';
import '../../utils/excel_value_utils.dart';
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

  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isReadingExcel = false;

  String? selectedExcelName;

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
  // ============================================================

  final sourceSlController = TextEditingController();
  final productCategoryController = TextEditingController();
  final printController = TextEditingController();

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
    final rawNames = detail['_image_names'];

    final List<String> expectedNames = rawNames is List
        ? rawNames.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : imageNamesFromExcelValue(detail['file_name']);

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
        .map(platformFileToImageJson)
        .toList();
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
      imageNamesFromExcelValue(firstRow['IMAGE']);

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
        imageNamesFromExcelValue(row['IMAGE']);

        final model3DName =
        _modelNameFromExcelRow(row);

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

          // Excel-এর 3D MODEL / GLB filename.
          // API পাঠানোর আগে actual Base64 payload দিয়ে replace হবে।
          "_model_3d_name":
          model3DName,

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
        excelTableHeaders = headers
            .where(
              (header) =>
          header.isNotEmpty &&
              header != 'DISPLAY ROOM NO' &&
              header != 'ITEM QRCODE',
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
      excelTableHeaders = [];
      excelTableRows = [];
      selectedExcelImages.clear();
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
    final PlatformFile? firstImage =
    selectedImages.isNotEmpty ? selectedImages.first : null;

    final model3DPayload =
    _platformFileTo3DModelJson(selected3DModel);

    return {
      "source_sl": int.tryParse(
        sourceSlController.text.trim(),
      ),

      "product_category":
      productCategoryController.text.trim(),

      "print":
      printController.text.trim(),

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

      if (model3DPayload != null)
        "model_3d":
        model3DPayload,

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

    // ==========================================================
    // IMPORTANT
    //
    // Excel selected থাকলে -> Excel details[]
    // Excel না থাকলে -> Manual single detail
    // ==========================================================

    final List<Map<String, dynamic>> details;

    if (excelDetails.isNotEmpty) {
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


      "display_room_name":
      displayRoomNameController.text.trim(),

      "created_by":
      createdBy,

      "status":
      statusController.text.trim(),

      if (assignee != null)
        "assignee": assignee,

      "details":
      details,
    };

    final int totalImageCount = details.fold<int>(
      0,
          (sum, detail) =>
      sum + ((detail['images'] is List) ? (detail['images'] as List).length : 0),
    );

    final int total3DModelCount = details.fold<int>(
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
    debugPrint('==========================================');

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
                  first: buildTextField(
                    label: 'Business',
                    hint: 'e.g. Footwear',
                    controller: businessController,
                  ),
                  second: twoFields(
                    first: buildTextField(
                      label: 'Sub Category',
                      hint: 'e.g. Export',
                      controller: subCategoryController,
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

                twoFields(
                  first: buildTextField(
                    label: 'Display Room Name',
                    hint: 'e.g. MLIL-R10-Ftwr-Display Room',
                    controller: displayRoomNameController,
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
                    label: 'Product Category',
                    hint: 'e.g. Cemented',
                    controller: productCategoryController,
                  ),
                  second: buildTextField(
                    label: 'CBM',
                    hint: 'e.g. 54',
                    controller: cbmController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),

                gap(),

                Row(
                  children: [
                    Expanded(
                      child: buildTextField(
                        label: 'Item Code',
                        hint: 'e.g. 0100247925',
                        controller: itemCodeController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildTextField(
                        label: 'Sub Inventory Code',
                        hint: 'e.g. PN1.RM',
                        controller: subInventoryCodeController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildTextField(
                        label: 'Weight',
                        hint: 'e.g. 0.2',
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),

                gap(),

                buildTextField(
                  label: 'Description',
                  hint: 'e.g. LIDL SEMI FINISHED UPPER WHITE',
                  controller: descriptionController,
                  maxLines: 2,
                ),

                gap(),

                twoFields(
                  first: buildTextField(
                    label: 'UOM',
                    hint: 'e.g. Pair',
                    controller: uomController,
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
                  maxLines: 2,
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

    sourceSlController.dispose();
    productCategoryController.dispose();
    printController.dispose();
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
