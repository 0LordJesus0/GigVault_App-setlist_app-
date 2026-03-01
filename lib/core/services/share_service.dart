import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/setlist_model.dart';
import '../../data/models/song_model.dart';

class ShareService {
  
  static Future<void> exportData({
    required String exportTitle,
    required List<SongModel> songs,
    SetlistModel? setlistContext, 
    required bool includeDrawings,
  }) async {
    try {
      final drawingsBox = Hive.box<String>('drawings_box');
      List<Map<String, dynamic>> songsData = [];
      Map<String, String> drawingsData = {};

      for (var song in songs) {
        songsData.add({
          'id': song.id,
          'title': song.title,
          'content': song.content,
          'chordColor': song.chordColor,
          'transposeStep': song.transposeStep,
        });

        if (includeDrawings) {
          String? draws = drawingsBox.get(song.id);
          String? texts = drawingsBox.get('${song.id}_texts');
          if (draws != null) drawingsData[song.id] = draws;
          if (texts != null) drawingsData['${song.id}_texts'] = texts;
        }
      }

      Map<String, dynamic> exportPayload = {
        'type': 'GigVault_Export',
        'isSetlist': setlistContext != null,
        'setlist': setlistContext != null ? {
          'title': setlistContext.title,
          'themeColor': setlistContext.themeColor,
          'titleColor': setlistContext.titleColor,
        } : null,
        'songs': songsData,
        'drawings': drawingsData,
      };

      String jsonString = jsonEncode(exportPayload);
      final directory = await getTemporaryDirectory();
      String safeTitle = exportTitle.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
      
      final file = File('${directory.path}/$safeTitle.gigvault.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')], 
        text: '$exportTitle - GigVault Repertuvarı'
      );
    } catch (e) {
      debugPrint("Dışa Aktarma Hatası: $e");
    }
  }

  // DEDEKTİF MODU: Hataları net olarak döndürür
  static Future<String> importFromPath(String path) async {
    try {
      File file = File(path);
      if (!await file.exists()) {
        return "HATA: Dosya işletim sistemi tarafından gizlenmiş veya yol okunamıyor:\n$path";
      }
      String jsonString = await file.readAsString();
      return await importFromJsonString(jsonString);
    } catch (e) {
      return "OKUMA HATASI: $e";
    }
  }

  static Future<String> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result != null && result.files.single.path != null) {
        return await importFromPath(result.files.single.path!);
      }
      return "İPTAL: Dosya seçilmedi.";
    } catch (e) {
      return "SEÇİCİ HATASI: $e";
    }
  }

  static Future<String> importFromJsonString(String jsonString) async {
    try {
      Map<String, dynamic> data = jsonDecode(jsonString);

      if (data['type'] == 'GigVault_Export' || data['type'] == 'GigVault_Setlist') {
        final songsData = data['songs'] as List;
        final drawingsData = data['drawings'] as Map<String, dynamic>? ?? {};
        final bool isSetlist = data['isSetlist'] ?? (data['type'] == 'GigVault_Setlist');

        final songsBox = Hive.box<SongModel>('songs');
        final setlistsBox = Hive.box<SetlistModel>('setlists');
        final drawingsBox = Hive.box<String>('drawings_box');
        final uuid = const Uuid();

        List<String> newSongIds = [];

        for (var sData in songsData) {
          String newSongId = uuid.v4();
          newSongIds.add(newSongId);

          final newSong = SongModel(
            id: newSongId,
            title: sData['title'] ?? 'Bilinmeyen Şarkı',
            content: sData['content'] ?? '',
            chordColor: sData['chordColor'] ?? 'adaptive',
            transposeStep: sData['transposeStep'] ?? 0,
          );
          
          await songsBox.put(newSongId, newSong);

          String oldId = sData['id'];
          if (drawingsData.containsKey(oldId)) {
            await drawingsBox.put(newSongId, drawingsData[oldId]);
          }
          if (drawingsData.containsKey('${oldId}_texts')) {
            await drawingsBox.put('${newSongId}_texts', drawingsData['${oldId}_texts']);
          }
        }

        if (isSetlist && data['setlist'] != null) {
          final setlistData = data['setlist'];
          final newSetlist = SetlistModel(
            id: uuid.v4(),
            title: setlistData['title'] + " (İçe Aktarıldı)",
            themeColor: setlistData['themeColor'] ?? 'adaptive',
            titleColor: setlistData['titleColor'] ?? 'adaptive',
            songIds: newSongIds,
          );
          await setlistsBox.put(newSetlist.id, newSetlist);
        } else {
          final newSetlist = SetlistModel(
            id: uuid.v4(),
            title: "Paylaşılan Parçalar",
            themeColor: 'blue',
            titleColor: 'adaptive',
            songIds: newSongIds,
          );
          await setlistsBox.put(newSetlist.id, newSetlist);
        }
        return "OK";
      } else {
        return "HATA: Geçersiz bir GigVault dosyası.";
      }
    } catch (e) {
      return "HATA: Veri dönüştürülemedi. $e";
    }
  }
}