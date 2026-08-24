import 'package:flutter/material.dart';

import 'screens/delete/display_room_delete_page.dart';
import 'screens/item_list/display_room_item_list_page.dart';
import 'screens/item_upload/item_upload_screen.dart';

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
