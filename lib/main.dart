import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Az önce oluşturduğumuz veri modellerini projeye dahil ediyoruz
import 'data/models/setlist_model.dart';
import 'data/models/song_model.dart';
import 'features/setlist/setlist_screen.dart';

void main() async {
  // Flutter'ın arka plan sistemlerini başlatır
  WidgetsFlutterBinding.ensureInitialized();

  // Sahne için offline veritabanını (Hive) başlatır
  await Hive.initFlutter();
  
  // Asistanımızın (build_runner) ürettiği adaptörleri sisteme kaydediyoruz
  Hive.registerAdapter(SetlistModelAdapter());
  Hive.registerAdapter(SongModelAdapter());

  // Veritabanı kutularını (Tabloları) açıyoruz
  await Hive.openBox<SetlistModel>('setlists');
  await Hive.openBox<SongModel>('songs');
  
  // --- YENİ EKLENEN KUTULAR ---
  await Hive.openBox('settings'); // Tema, tam renk ve akor renk hafızası için
  await Hive.openBox<String>('drawings_box'); // Çizimlerin kalıcı olması için

  runApp(
    // Durum yönetimi (State Management) için uygulamayı Riverpod ile sarıyoruz
    const ProviderScope(
      child: ProSetlistApp(),
    ),
  );
}

class ProSetlistApp extends StatelessWidget {
  const ProSetlistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Setlist',
      debugShowCheckedModeBanner: false, // Sahnede kırmızı 'Debug' bandını gizler
      themeMode: ThemeMode.dark, // Daima Karanlık Tema
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black, // Gerçek siyah (OLED dostu)
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent, // Vurgu rengi
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
      ),
      home: const SetlistScreen(), // Bir sonraki adımda buraya kendi Setlist sayfamızı koyacağız
    );
  }
}