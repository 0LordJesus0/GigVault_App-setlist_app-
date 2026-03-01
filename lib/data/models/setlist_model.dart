import 'package:hive/hive.dart';

// Bu satır başta kırmızı altı çizili olacak, panik yok! Birazdan üreteceğiz.
part 'setlist_model.g.dart'; 

@HiveType(typeId: 0)
class SetlistModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String titleColor; // Başlık rengi (Kullanıcı değiştirebilir)

  @HiveField(3)
  String themeColor; // Setlist'in birbirine yakın tonlardaki genel teması

  @HiveField(4)
  List<String> songIds; // Setlist içindeki şarkıların ID'leri (Sıralama için)

  @HiveField(5)
  bool isActive; // Sahnede o an bu setlist mi açık? (Arama önceliği için)

  SetlistModel({
    required this.id,
    required this.title,
    required this.titleColor,
    required this.themeColor,
    required this.songIds,
    this.isActive = false,
  });
}