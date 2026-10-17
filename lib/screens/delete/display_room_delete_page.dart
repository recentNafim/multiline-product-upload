import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/delete_models.dart';
import '../../services/display_room_api_service.dart';

class DisplayRoomDeletePage extends StatefulWidget {
  const DisplayRoomDeletePage({super.key});
  @override
  State<DisplayRoomDeletePage> createState() => _DisplayRoomDeletePageState();
}

class _DisplayRoomDeletePageState extends State<DisplayRoomDeletePage> {
  final searchController = TextEditingController();
  bool isLoading = false;
  bool deleting = false;
  String? error;
  List<DeleteProductRow> products = [];
  List<DeleteMasterRow> masters = [];

  @override
  void initState() {
    super.initState();
    searchController.addListener(() { if (mounted) setState(() {}); });
    _load();
  }

  DeleteParsedData _parse(dynamic json) {
    final data = json is List ? json : (json is Map
      ? json['data'] ?? json['items'] ?? json['item_list'] : null);
    final result = <DeleteProductRow>[];
    final masterRows = <DeleteMasterRow>[];
    if (data is List) {
      for (final raw in data) {
        if (raw is! Map) continue;
        final master = Map<String, dynamic>.from(raw);
        final sl = deleteAsInt(master['sl'] ?? master['master_sl']);
        final business = deleteAsText(master['business']);
        final sub = deleteAsText(master['sub_category']);
        final roomNo = deleteAsText(master['display_room_no']);
        final roomName = deleteAsText(master['display_room_name']);
        final orgCode = deleteAsText(master['organization_code']);
        final details = master['details'];
        final children = details is List ? details : (master.containsKey('item_code')
            ? <dynamic>[master] : <dynamic>[]);
        masterRows.add(DeleteMasterRow(
          masterSl: sl, business: business, subCategory: sub,
          displayRoomNo: roomNo, displayRoomName: roomName,
          organizationCode: orgCode, organizationId: deleteAsInt(master['organization_id']),
          status: deleteAsText(master['status']), detailsCount: children.length,
        ));
        for (final rawDetail in children) {
          if (rawDetail is! Map) continue;
          final d = Map<String, dynamic>.from(rawDetail);
          final images = d['images'];
          String image = deleteAsText(d['file_url']);
          if (image.isEmpty && images is List && images.isNotEmpty) {
            final photo = images.first;
            image = photo is Map ? deleteAsText(photo['image_url'] ?? photo['file_url'])
              : deleteAsText(photo);
          }
          result.add(DeleteProductRow(
            detailSl: deleteAsInt(d['sl'] ?? d['detail_sl']),
            masterSl: sl, itemCode: deleteAsText(d['item_code']),
            description: deleteAsText(d['description']),
            productCategory: deleteAsText(d['product_category']),
            business: business, subCategory: sub,
            displayRoomNo: roomNo, displayRoomName: roomName, imageUrl: image,
          ));
        }
      }
    }
    return DeleteParsedData(products: result, masters: masterRows);
  }

  Future<void> _load() async {
    if (isLoading) return;
    setState(() { isLoading = true; error = null; });
    try {
      final response = await DisplayRoomApiService.getDeleteData();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final parsed = _parse(jsonDecode(response.body));
      if (!mounted) return;
      setState(() { products = parsed.products; masters = parsed.masters; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<bool> _confirm(String title, String detail) async {
    if (!mounted) return false;
    return await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
      title: Text(title), content: Text(detail),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete')),
      ],
    )) ?? false;
  }

  Future<void> _deleteProduct(DeleteProductRow item) async {
    if (item.detailSl == null || deleting) return;
    final related = products.where((p) => p.masterSl == item.masterSl).toList();
    final lastProduct = related.length == 1 && item.masterSl != null;
    final ok = await _confirm('Delete ${item.itemCode}?', lastProduct
      ? 'This is the last product in this display room. Delete the product and its master record?'
      : 'Delete this product and its images permanently?');
    if (!ok || !mounted) return;
    setState(() => deleting = true);
    try {
      final response = lastProduct
        ? await DisplayRoomApiService.deleteMaster(item.masterSl!)
        : await DisplayRoomApiService.deleteProduct(item.detailSl!);
      final data = _readResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300 ||
          (data is Map && data['status_code'] != null &&
           data['status_code'].toString() != '200')) {
        throw Exception(data is Map ? data['message'] ?? response.body : response.body);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
    await _load();
  }

  dynamic _readResponse(String text) {
    try { return jsonDecode(text); } catch (_) { return text; }
  }

  Future<void> _deleteMaster(DeleteMasterRow master) async {
    if (master.masterSl == null || deleting) return;
    final ok = await _confirm('Delete display room?',
      'Delete ${master.displayRoomName} and all its products permanently?');
    if (!ok || !mounted) return;
    setState(() => deleting = true);
    try {
      final response = await DisplayRoomApiService.deleteMaster(master.masterSl!);
      final data = _readResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300 ||
          (data is Map && data['status_code'] != null &&
            data['status_code'].toString() != '200')) {
        throw Exception(data is Map ? data['message'] ?? response.body : response.body);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display room deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final filtered = products.where((p) => query.isEmpty ||
      [p.itemCode, p.description, p.business, p.productCategory,
        p.displayRoomName].any((value) => value.toLowerCase().contains(query))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Products'), actions: [
        IconButton(onPressed: isLoading || deleting ? null : _load,
          icon: const Icon(Icons.refresh)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          controller: searchController,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            hintText: 'Search item code, category, room...'),
        )),
        if (isLoading || deleting) const LinearProgressIndicator(),
        if (error != null) Padding(padding: const EdgeInsets.all(16),
          child: Text(error!, style: const TextStyle(color: Colors.red))),
        Expanded(child: ListView(children: [
          if (filtered.isNotEmpty) const Padding(
            padding: EdgeInsets.all(12), child: Text('Products',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ...filtered.map((p) => Card(margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ListTile(
              title: Text(p.description.isEmpty ? p.itemCode : p.description),
              subtitle: Text('${p.itemCode}  •  ${p.business}  •  ${p.displayRoomName}'),
              trailing: IconButton(tooltip: 'Delete product',
                onPressed: deleting ? null : () => _deleteProduct(p),
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent)),
            ),
          )),
          const Padding(padding: EdgeInsets.all(12), child: Text('Display rooms',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ...masters.where((m) => query.isEmpty ||
            [m.displayRoomName, m.business].any((x) => x.toLowerCase().contains(query)))
          .map((m) => Card(margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ListTile(
              title: Text(m.displayRoomName.isEmpty ? m.displayRoomNo : m.displayRoomName),
              subtitle: Text('${m.business}  •  ${m.detailsCount} products'),
              trailing: IconButton(tooltip: 'Delete display room',
                onPressed: deleting ? null : () => _deleteMaster(m),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
            ),
          )),
        ])),
      ]),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
