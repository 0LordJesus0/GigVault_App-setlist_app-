import 'package:hive/hive.dart';

// Yine kırmızı altı çizili olacak, normaldir.
part 'song_model.g.dart'; 

@HiveType(typeId: 1)
class SongModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content; // Şarkı sözleri ve içine gömülü akorların tamamı

  @HiveField(3)
  int transposeStep; // Dokunulmaz alan: Transpoze hafızası (+1, -2 yarım ses vb.)

  @HiveField(4)
  String chordColor; // Akor renk sistemi (Kırmızı, Yeşil, Mavi vb.)

  SongModel({
    required this.id,
    required this.title,
    required this.content,
    this.transposeStep = 0,
    this.chordColor = 'blue', // Varsayılan akor rengi
  });
}