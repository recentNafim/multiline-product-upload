import 'package:flutter/material.dart';
import 'services/auth_session.dart';
import 'widgets/auth_guard.dart';
import 'screens/delete/display_room_delete_page.dart';
import 'screens/bulk_image_update/bulk_image_update_page.dart';
import 'screens/item_list/display_room_item_list_page.dart';
import 'screens/item_upload/item_upload_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AuthSession.instance.initialize();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AuthSession.instance,
    builder: (context, _) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MLIL Product Upload Admin',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true),
        home: AuthGuard(child: const ItemUploadScreen()),
        routes: {
          '/items': (_) => const AuthGuard(child: DisplayRoomItemListPage()),
          '/delete': (_) => const AuthGuard(child: DisplayRoomDeletePage()),
          '/bulk-images': (_) => const AuthGuard(child: BulkImageUpdatePage()),
        },
      );
    },
  );
}

