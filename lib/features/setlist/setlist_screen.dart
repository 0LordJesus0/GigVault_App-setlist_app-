import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../data/models/setlist_model.dart';
import '../../data/models/song_model.dart';
import '../../core/services/share_service.dart';
import 'setlist_detail_screen.dart';

final appNameProvider = StateProvider<String>((ref) {
  return Hive.box('settings').get('appName', defaultValue: 'GigVault');
});
final isDarkModeProvider = StateProvider<bool>((ref) {
  return Hive.box('settings').get('isDarkMode', defaultValue: true);
});
final appThemeColorProvider = StateProvider<Color>((ref) {
  final val = Hive.box('settings').get('appThemeColor', defaultValue: Colors.transparent.value);
  return Color(val);
}); 
final filledCardsProvider = StateProvider<bool>((ref) {
  return Hive.box('settings').get('isFullColor', defaultValue: false);
});
final appLanguageProvider = StateProvider<String>((ref) {
  return Hive.box('settings').get('appLanguage', defaultValue: 'tr');
});

const Map<String, Map<String, String>> _t = {
  'searchHint': {'tr': 'Setlist veya Şarkı Ara...', 'en': 'Search Setlist or Song...', 'de': 'Setlist oder Song suchen...'},
  'lost': {'tr': 'Kayıp...', 'en': 'Lost...', 'de': 'Verloren...'},
  'emptyTitle': {'tr': 'Repertuvarın seni bekliyor...', 'en': 'Your repertoire awaits...', 'de': 'Dein Repertoire wartet...'},
  'emptySub': {'tr': 'Hadi ilk setlistini oluştur ve\nakorlarını biriktirmeye başla.', 'en': 'Create your first setlist and\nstart collecting your chords.', 'de': 'Erstelle deine erste Setliste und\nsammle deine Akkorde.'},
  'tracks': {'tr': 'Parça', 'en': 'Tracks', 'de': 'Titel'},
  'settings': {'tr': 'SAHNE AYARLARI', 'en': 'STAGE SETTINGS', 'de': 'BÜHNEN EINSTELLUNGEN'},
  'appName': {'tr': 'Uygulama Adı', 'en': 'App Name', 'de': 'App-Name'},
  'darkMode': {'tr': 'Karanlık Sahne (Gece Modu)', 'en': 'Dark Stage (Night Mode)', 'de': 'Dunkle Bühne (Nachtmodus)'},
  'filledCards': {'tr': 'Tamamen Renkli Setlist Kutuları', 'en': 'Fully Colored Setlist Cards', 'de': 'Vollfarbige Setlist-Karten'},
  'filledCardsSub': {'tr': 'Kutuların sadece kenarları değil, içi de renkle dolar.', 'en': 'Cards are fully colored, not just the borders.', 'de': 'Karten sind vollfarbig, nicht nur die Ränder.'},
  'mainTheme': {'tr': 'Ana Tema Rengi', 'en': 'Main Theme Color', 'de': 'Hauptthema Farbe'},
  'language': {'tr': 'Dil / Language / Sprache', 'en': 'Language', 'de': 'Sprache'},
  'areYouSure': {'tr': 'Emin misin?', 'en': 'Are you sure?', 'de': 'Bist du sicher?'},
  'deleteWarning': {'tr': ' adlı liste kalıcı olarak silinecek. İçindeki şarkıların kendisi veritabanında kalır ama bu liste kaybolur.', 'en': ' will be permanently deleted. Songs remain in the database, but this list will be lost.', 'de': ' wird dauerhaft gelöscht. Songs bleiben erhalten, aber diese Liste geht verloren.'},
  'cancel': {'tr': 'İPTAL', 'en': 'CANCEL', 'de': 'ABBRECHEN'},
  'delete': {'tr': 'SİL', 'en': 'DELETE', 'de': 'LÖSCHEN'},
  'edit': {'tr': 'DÜZENLE', 'en': 'EDIT', 'de': 'BEARBEITEN'},
  'share': {'tr': 'PAYLAŞ', 'en': 'SHARE', 'de': 'TEILEN'},
  'importSuccess': {'tr': 'Repertuvar başarıyla içe aktarıldı!', 'en': 'Repertoire imported successfully!', 'de': 'Repertoire erfolgreich importiert!'},
  'importFail': {'tr': 'İçe aktarma başarısız veya dosya hatalı.', 'en': 'Import failed or invalid file.', 'de': 'Import fehlgeschlagen oder ungültige Datei.'},
  'newPerformance': {'tr': 'Yeni Performans', 'en': 'New Performance', 'de': 'Neuer Auftritt'},
  'editPerformance': {'tr': 'Performansı Düzenle', 'en': 'Edit Performance', 'de': 'Auftritt Bearbeiten'},
  'titleHint': {'tr': 'Başlık (Örn: Cumartesi Kadıköy)', 'en': 'Title (e.g., Saturday Gig)', 'de': 'Titel (z.B. Samstag Gig)'},
  'colorPalette': {'tr': 'Setlist Rengi', 'en': 'Setlist Color', 'de': 'Setlist-Farbe'},
  'create': {'tr': 'OLUŞTUR', 'en': 'CREATE', 'de': 'ERSTELLEN'},
  'update': {'tr': 'GÜNCELLE', 'en': 'UPDATE', 'de': 'AKTUALISIEREN'},
  'existsError': {'tr': 'Bu isimde bir performans zaten var!', 'en': 'A performance with this name already exists!', 'de': 'Ein Auftritt mit diesem Namen existiert bereits!'},
  'shareOptions': {'tr': 'Paylaşım Seçenekleri', 'en': 'Share Options', 'de': 'Freigabeoptionen'},
  'shareAllWithDrawings': {'tr': 'Tümünü Paylaş (Çizimler Dahil)', 'en': 'Share All (With Drawings)', 'de': 'Alle Teilen (Mit Zeichnungen)'},
  'shareAllTextOnly': {'tr': 'Tümünü Paylaş (Sadece Metin)', 'en': 'Share All (Text Only)', 'de': 'Alle Teilen (Nur Text)'},
};

class SetlistScreen extends ConsumerStatefulWidget {
  const SetlistScreen({super.key});

  @override
  ConsumerState<SetlistScreen> createState() => _SetlistScreenState();
}

class _SetlistScreenState extends ConsumerState<SetlistScreen> {
  final _uuid = const Uuid();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  late StreamSubscription _intentMediaStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupShareIntentListener();
  }

  void _setupShareIntentListener() {
    _intentMediaStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) _handleIncomingData(value.first.path);
    });
    
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleIncomingData(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _handleIncomingData(String data) async {
    String result;
    if (data.startsWith('{') && data.contains('GigVault')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Format: Metin Yakalandı! İşleniyor...")));
      result = await ShareService.importFromJsonString(data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Format: Dosya Yakalandı!\nYol: $data")));
      result = await ShareService.importFromPath(data);
    }
    _showResult(result);
  }

  void _showResult(String result) {
    if (!mounted) return;
    if (result == "OK") {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getText('importSuccess', ref.read(appLanguageProvider)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade800));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 8)));
    }
  }

  @override
  void dispose() {
    _intentMediaStreamSubscription.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String getText(String key, String lang) {
    return _t[key]?[lang] ?? _t[key]?['en'] ?? key;
  }

  Color _getAdaptedThemeColor(String colorName, bool isDark) {
    if (colorName == 'adaptive' || colorName == 'white' || colorName == 'black') {
      return isDark ? Colors.white : Colors.black87;
    }
    
    Color originalColor = _getColorFromString(colorName);
    
    if (isDark) {
      if (colorName == 'nightBlue') return const Color(0xFF3949AB); 
    } else {
      if (colorName == 'yellow') return Colors.orange.shade700;
      if (colorName == 'cyan') return Colors.cyan.shade800;
      if (colorName == 'green') return Colors.green.shade800;
    }
    
    return originalColor;
  }

  Color _getColorFromString(String colorString) {
    switch (colorString) {
      case 'red': return const Color(0xFFFF0033); 
      case 'orange': return const Color(0xFFFF6600); 
      case 'yellow': return Colors.yellowAccent;
      case 'green': return const Color(0xFF39FF14); 
      case 'cyan': return Colors.cyanAccent;
      case 'blue': return Colors.blueAccent;
      case 'nightBlue': return const Color(0xFF0014A8); 
      case 'purple': return const Color(0xFF9D00FF); 
      case 'magenta': return const Color(0xFFFF00FF); 
      case 'pink': return const Color(0xFFFF1493); 
      case 'adaptive': return Colors.transparent;
      default: return const Color(0xFFFF0033);
    }
  }

  bool _isLightColorForBg(Color color) {
    if (color == Colors.transparent) return false;
    return color.computeLuminance() > 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final appName = ref.watch(appNameProvider);
    final isDark = ref.watch(isDarkModeProvider);
    final rawThemeColor = ref.watch(appThemeColorProvider);
    final isFilled = ref.watch(filledCardsProvider);
    final lang = ref.watch(appLanguageProvider);

    final appThemeColor = rawThemeColor == Colors.transparent 
        ? (isDark ? Colors.white : Colors.black87) 
        : rawThemeColor;

    final bgColor = isDark ? Colors.black : const Color(0xFFF0F0F3);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return ValueListenableBuilder(
      valueListenable: Hive.box<SetlistModel>('setlists').listenable(),
      builder: (context, Box<SetlistModel> box, _) {
        
        var allSetlists = box.values.toList();
        if (_searchQuery.isNotEmpty) {
          final songsBox = Hive.box<SongModel>('songs');
          allSetlists = allSetlists.where((setlist) {
            bool titleMatches = setlist.title.toLowerCase().contains(_searchQuery);
            bool songMatches = setlist.songIds.any((songId) {
              var song = songsBox.get(songId);
              return song != null && song.title.toLowerCase().contains(_searchQuery);
            });
            return titleMatches || songMatches;
          }).toList();
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: _buildAppBar(appName, appThemeColor, isDark, textColor, subTextColor, lang),
          body: allSetlists.isEmpty 
              ? _buildEmptyStage(appThemeColor, isDark, textColor, subTextColor, lang) 
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allSetlists.length,
                  itemBuilder: (context, index) {
                    SetlistModel currentSetlist = allSetlists[index];
                    return _buildNeonSetlistCard(currentSetlist, box, isDark, isFilled, textColor, subTextColor, lang);
                  },
                ),
          floatingActionButton: _buildFab(context, appThemeColor, lang),
        );
      },
    );
  }

  AppBar _buildAppBar(String appName, Color themeColor, bool isDark, Color textColor, Color subTextColor, String lang) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      elevation: 0,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: GoogleFonts.montserrat(color: textColor, fontSize: 18),
              cursorColor: themeColor,
              decoration: InputDecoration(
                hintText: getText('searchHint', lang),
                hintStyle: GoogleFonts.montserrat(color: subTextColor),
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
            )
          : Text(
              appName, 
              style: GoogleFonts.bebasNeue( 
                letterSpacing: 3.0,
                color: textColor,
                fontSize: 28, 
              ),
            ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, size: 28, color: textColor),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _isSearching = false;
                _searchController.clear();
                _searchQuery = '';
              } else {
                _isSearching = true;
              }
            });
          },
        ),
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.file_download_outlined, size: 28, color: textColor),
            onPressed: () async {
              String result = await ShareService.importData();
              _showResult(result);
            },
          ),
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 28, color: textColor),
            onPressed: () => _showSettingsPanel(context),
          ),
      ],
    );
  }

  Widget _buildEmptyStage(Color themeColor, bool isDark, Color textColor, Color subTextColor, String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF141414) : Colors.white,
              border: Border.all(color: themeColor.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(color: themeColor.withOpacity(0.15), blurRadius: 40, spreadRadius: 5),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 70, color: themeColor.withOpacity(0.4)),
                Icon(Icons.music_note_rounded, size: 40, color: themeColor),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            _searchQuery.isNotEmpty ? getText('lost', lang) : getText('emptyTitle', lang),
            style: GoogleFonts.montserrat(
              color: textColor.withOpacity(0.85), 
              fontSize: 20, 
              fontWeight: FontWeight.w400, 
              letterSpacing: 1.0
            ),
          ),
          const SizedBox(height: 12),
          Text(
            getText('emptySub', lang),
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor.withOpacity(0.7), fontSize: 16, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context, Color themeColor, String lang) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.25), 
            blurRadius: 12, 
            spreadRadius: 0, 
            offset: const Offset(0, 4) 
          )
        ]
      ),
      child: FloatingActionButton(
        onPressed: () => _showAddSetlistDialog(context, themeColor, lang),
        backgroundColor: themeColor,
        elevation: 0,
        child: Icon(Icons.add, color: _isLightColorForBg(themeColor) ? Colors.black87 : Colors.white, size: 36),
      ),
    );
  }

  Widget _buildNeonSetlistCard(SetlistModel setlist, Box<SetlistModel> box, bool isDark, bool isFilled, Color defaultTextColor, Color defaultSubTextColor, String lang) {
    Color cardThemeColor = _getAdaptedThemeColor(setlist.themeColor, isDark);
    bool isAdaptive = setlist.themeColor == 'adaptive' || setlist.themeColor == 'white' || setlist.themeColor == 'black';

    Color cardBgColor = isFilled ? cardThemeColor : (isDark ? const Color(0xFF161616) : Colors.white);
    Color titleColor = isFilled ? (_isLightColorForBg(cardThemeColor) ? Colors.black87 : Colors.white) : defaultTextColor;
    Color subtitleColor = isFilled ? (_isLightColorForBg(cardThemeColor) ? Colors.black54 : Colors.white70) : defaultSubTextColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFilled 
              ? Colors.transparent 
              : (isAdaptive && isDark ? Colors.white38 : (isAdaptive && !isDark ? Colors.black26 : cardThemeColor.withOpacity(0.4))), 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: isAdaptive && isDark ? Colors.white10 : cardThemeColor.withOpacity(isFilled ? 0.3 : 0.15), 
            blurRadius: 20, 
            spreadRadius: 2
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SetlistDetailScreen(
                  setlist: setlist, 
                  initialSearchQuery: _searchQuery.isNotEmpty ? _searchQuery : null
                ),
              ),
            );
          },
          onLongPress: () {
            _showSetlistOptionsPanel(context, setlist, box, isDark, cardThemeColor, lang);
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                if (!isFilled) 
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cardThemeColor,
                      shape: BoxShape.circle,
                      border: (isAdaptive && isDark) || (isAdaptive && !isDark) ? Border.all(color: Colors.grey, width: 1) : null,
                      boxShadow: isAdaptive ? [] : [BoxShadow(color: cardThemeColor, blurRadius: 8, spreadRadius: 1)]
                    ),
                  ),
                if (!isFilled) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setlist.title,
                        style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w600, color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${setlist.songIds.length} ${getText('tracks', lang)}',
                        style: TextStyle(color: subtitleColor, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSetlistOptionsPanel(BuildContext context, SetlistModel setlist, Box<SetlistModel> box, bool isDark, Color themeColor, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: Colors.blueAccent),
                  title: Text(getText('share', lang), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  onTap: () {
                    Navigator.pop(context);
                    final songsBox = Hive.box<SongModel>('songs');
                    final allSongs = setlist.songIds.map((id) => songsBox.get(id)).whereType<SongModel>().toList();
                    
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(getText('shareOptions', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.brush, color: Colors.blueAccent),
                                title: Text(getText('shareAllWithDrawings', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                onTap: () {
                                  Navigator.pop(context);
                                  ShareService.exportData(exportTitle: setlist.title, songs: allSongs, setlistContext: setlist, includeDrawings: true);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.text_fields, color: Colors.orangeAccent),
                                title: Text(getText('shareAllTextOnly', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                onTap: () {
                                  Navigator.pop(context);
                                  ShareService.exportData(exportTitle: setlist.title, songs: allSongs, setlistContext: setlist, includeDrawings: false);
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: themeColor),
                  title: Text(getText('edit', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  onTap: () {
                    Navigator.pop(context);
                    Color originalAppTheme = ref.read(appThemeColorProvider) == Colors.transparent 
                        ? (isDark ? Colors.white : Colors.black87) 
                        : ref.read(appThemeColorProvider);
                    _showEditSetlistDialog(context, originalAppTheme, lang, setlist); 
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text(getText('delete', lang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  onTap: () {
                    Navigator.pop(context); 
                    _showDeleteConfirmation(context, box, setlist, isDark, lang); 
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showSettingsPanel(BuildContext context) {
    final nameCtrl = TextEditingController(text: ref.read(appNameProvider));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final rawThemeColor = ref.watch(appThemeColorProvider);
            final currentIsDark = ref.watch(isDarkModeProvider);
            final currentIsFilled = ref.watch(filledCardsProvider);
            final lang = ref.watch(appLanguageProvider);

            Color appThemeColor = rawThemeColor == Colors.transparent 
                ? (currentIsDark ? Colors.white : Colors.black87) 
                : rawThemeColor;

            final bgColor = currentIsDark ? const Color(0xFF1A1A1A) : Colors.white;
            final textColor = currentIsDark ? Colors.white : Colors.black87;
            final subTextColor = currentIsDark ? Colors.white54 : Colors.black54;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getText('settings', lang), style: GoogleFonts.montserrat(color: textColor, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 24),
                      
                      TextField(
                        controller: nameCtrl,
                        maxLength: 15, 
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: textColor, fontSize: 18),
                        decoration: InputDecoration(
                          labelText: getText('appName', lang),
                          labelStyle: TextStyle(color: subTextColor),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: subTextColor.withOpacity(0.3))),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: appThemeColor)),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.check, color: appThemeColor),
                            onPressed: () {
                              if (nameCtrl.text.trim().isNotEmpty) {
                                String newName = nameCtrl.text.trim();
                                ref.read(appNameProvider.notifier).state = newName;
                                Hive.box('settings').put('appName', newName); 
                                FocusScope.of(context).unfocus(); 
                              }
                            },
                          )
                        ),
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: Text(getText('darkMode', lang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        activeColor: appThemeColor,
                        contentPadding: EdgeInsets.zero,
                        value: currentIsDark,
                        onChanged: (val) {
                          ref.read(isDarkModeProvider.notifier).state = val;
                          Hive.box('settings').put('isDarkMode', val); 
                        }
                      ),

                      SwitchListTile(
                        title: Text(getText('filledCards', lang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        subtitle: Text(getText('filledCardsSub', lang), style: TextStyle(color: subTextColor, fontSize: 12)),
                        activeColor: appThemeColor,
                        contentPadding: EdgeInsets.zero,
                        value: currentIsFilled,
                        onChanged: (val) {
                          ref.read(filledCardsProvider.notifier).state = val;
                          Hive.box('settings').put('isFullColor', val); 
                        }
                      ),
                      const SizedBox(height: 24),

                      Text(getText('mainTheme', lang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      
                      SizedBox(
                        height: 64, 
                        child: ListView(
                          clipBehavior: Clip.none,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                          children: [
                            _buildMainThemeColorOption(const Color(0xFFFF0033), rawThemeColor, ref, currentIsDark), 
                            _buildMainThemeColorOption(const Color(0xFFFF6600), rawThemeColor, ref, currentIsDark), 
                            _buildMainThemeColorOption(Colors.yellowAccent, rawThemeColor, ref, currentIsDark),    
                            _buildMainThemeColorOption(const Color(0xFF39FF14), rawThemeColor, ref, currentIsDark), 
                            _buildMainThemeColorOption(Colors.cyanAccent, rawThemeColor, ref, currentIsDark),      
                            _buildMainThemeColorOption(Colors.blueAccent, rawThemeColor, ref, currentIsDark),      
                            _buildMainThemeColorOption(const Color(0xFF0014A8), rawThemeColor, ref, currentIsDark), 
                            _buildMainThemeColorOption(const Color(0xFF9D00FF), rawThemeColor, ref, currentIsDark), 
                            _buildMainThemeColorOption(const Color(0xFFFF00FF), rawThemeColor, ref, currentIsDark), 
                            _buildMainThemeColorOption(const Color(0xFFFF1493), rawThemeColor, ref, currentIsDark), 
                            _buildMainThemeColorOption(Colors.transparent, rawThemeColor, ref, currentIsDark, isAdaptive: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(getText('language', lang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildLangOption('tr', 'Türkçe', lang, appThemeColor, ref, textColor, currentIsDark),
                          const SizedBox(width: 12),
                          _buildLangOption('en', 'English', lang, appThemeColor, ref, textColor, currentIsDark),
                          const SizedBox(width: 12),
                          _buildLangOption('de', 'Deutsch', lang, appThemeColor, ref, textColor, currentIsDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildMainThemeColorOption(Color color, Color currentColor, WidgetRef ref, bool isDark, {bool isAdaptive = false}) {
    bool isSelected = currentColor == color; 
    
    Color actualSwatchColor;
    if (isAdaptive) {
       actualSwatchColor = Colors.transparent; 
    } else {
       actualSwatchColor = color;
    }

    Color displayColor = isAdaptive ? (isDark ? Colors.white : Colors.black87) : actualSwatchColor;

    return GestureDetector(
      onTap: () {
        ref.read(appThemeColorProvider.notifier).state = color;
        Hive.box('settings').put('appThemeColor', color.value); 
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16), 
        width: 38, 
        height: 38,
        decoration: BoxDecoration(
          color: isAdaptive ? null : actualSwatchColor, 
          gradient: isAdaptive ? const LinearGradient(
            colors: [Colors.black, Colors.white],
            stops: [0.5, 0.5],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          shape: BoxShape.circle,
          border: isSelected 
              ? Border.all(color: isDark ? Colors.white : Colors.black87, width: 3) 
              : Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: isAdaptive && isDark ? Colors.white.withOpacity(isSelected ? 0.3 : 0.0) : actualSwatchColor.withOpacity(isSelected ? 0.6 : 0.2),
              blurRadius: isSelected ? 10 : 4,
              spreadRadius: isSelected ? 1 : 0, 
            )
          ],
        ),
        child: isSelected ? Icon(Icons.check, color: isAdaptive ? Colors.redAccent : (_isLightColorForBg(displayColor) ? Colors.black87 : Colors.white), size: 18) : null,
      ),
    );
  }

  Widget _buildLangOption(String langCode, String label, String currentLang, Color themeColor, WidgetRef ref, Color textColor, bool isDark) {
    bool isSelected = currentLang == langCode;
    return GestureDetector(
      onTap: () {
        ref.read(appLanguageProvider.notifier).state = langCode;
        Hive.box('settings').put('appLanguage', langCode); 
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? themeColor : (isDark ? Colors.white24 : Colors.black12), width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? themeColor : textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Box<SetlistModel> box, SetlistModel setlist, bool isDark, String lang) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Text(getText('areYouSure', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          content: Text(
            '"${setlist.title}"${getText('deleteWarning', lang)}',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(getText('cancel', lang), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
              onPressed: () {
                setlist.delete(); 
                Navigator.pop(context);
              },
              child: Text(getText('delete', lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddSetlistDialog(BuildContext context, Color appThemeColor, String lang) {
    _showSetlistFormDialog(context, appThemeColor, lang, isEditMode: false);
  }

  void _showEditSetlistDialog(BuildContext context, Color appThemeColor, String lang, SetlistModel setlist) {
    _showSetlistFormDialog(context, appThemeColor, lang, isEditMode: true, existingSetlist: setlist);
  }

  void _showSetlistFormDialog(BuildContext context, Color appThemeColor, String lang, {required bool isEditMode, SetlistModel? existingSetlist}) {
    final titleController = TextEditingController(text: isEditMode ? existingSetlist!.title : '');
    
    String initialColor = isEditMode ? existingSetlist!.themeColor : 'adaptive';
    if (initialColor == 'white' || initialColor == 'black') initialColor = 'adaptive';
    String selectedColor = initialColor; 
    
    String? errorMessage; 
    final isDark = ref.read(isDarkModeProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEditMode ? getText('editPerformance', lang) : getText('newPerformance', lang), 
                style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)
              ),
              content: SingleChildScrollView(
                clipBehavior: Clip.none, 
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        maxLength: 15, 
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, 
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: getText('titleHint', lang),
                          labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: appThemeColor)),
                          errorText: errorMessage, 
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        autofocus: true,
                        onChanged: (val) {
                          if (errorMessage != null) setState(() => errorMessage = null);
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(getText('colorPalette', lang), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14)),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0, left: 4, right: 4), 
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center, 
                            clipBehavior: Clip.none, 
                            spacing: 16, 
                            runSpacing: 16,
                            children: [
                              _buildDialogColorOption('red', const Color(0xFFFF0033), selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('orange', const Color(0xFFFF6600), selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('yellow', Colors.yellowAccent, selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('green', const Color(0xFF39FF14), selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('cyan', Colors.cyanAccent, selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('blue', Colors.blueAccent, selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('nightBlue', const Color(0xFF0014A8), selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('purple', const Color(0xFF9D00FF), selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('magenta', const Color(0xFFFF00FF), selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('pink', const Color(0xFFFF1493), selectedColor, isDark, (val) => setState(() => selectedColor = val)),
                              _buildDialogColorOption('adaptive', Colors.transparent, selectedColor, isDark, (val) => setState(() => selectedColor = val), isAdaptive: true),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(getText('cancel', lang), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getAdaptedThemeColor(selectedColor, isDark), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 4, 
                    shadowColor: _getAdaptedThemeColor(selectedColor, isDark).withOpacity(0.25), 
                  ),
                  onPressed: () {
                    String title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final box = Hive.box<SetlistModel>('setlists');
                    
                    bool alreadyExists = isEditMode 
                        ? box.values.any((s) => s.id != existingSetlist!.id && s.title.toLowerCase() == title.toLowerCase())
                        : box.values.any((s) => s.title.toLowerCase() == title.toLowerCase());

                    if (alreadyExists) {
                      setState(() => errorMessage = getText('existsError', lang));
                      return; 
                    }

                    if (isEditMode) {
                      existingSetlist!.title = title;
                      existingSetlist.themeColor = selectedColor;
                      existingSetlist.save(); 
                    } else {
                      final newSetlist = SetlistModel(
                        id: _uuid.v4(),
                        title: title,
                        titleColor: 'adaptive', 
                        themeColor: selectedColor,
                        songIds: [],
                      );
                      box.add(newSetlist);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(
                    isEditMode ? getText('update', lang) : getText('create', lang), 
                    style: TextStyle(
                      color: _isLightColorForBg(_getAdaptedThemeColor(selectedColor, isDark)) ? Colors.black87 : Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 16
                    )
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildDialogColorOption(String colorName, Color color, String selectedColor, bool isDark, Function(String) onSelect, {bool isAdaptive = false}) {
    bool isSelected = selectedColor == colorName;
    
    Color actualSwatchColor;
    if (isAdaptive) {
       actualSwatchColor = Colors.transparent; 
    } else {
       actualSwatchColor = _getAdaptedThemeColor(colorName, isDark);
    }

    Color displayColor = isAdaptive ? (isDark ? Colors.white : Colors.black87) : actualSwatchColor;

    return GestureDetector(
      onTap: () => onSelect(colorName),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isAdaptive ? null : actualSwatchColor, 
          gradient: isAdaptive ? const LinearGradient(
            colors: [Colors.black, Colors.white],
            stops: [0.5, 0.5],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          shape: BoxShape.circle,
          border: isSelected 
              ? Border.all(color: isDark ? Colors.white : Colors.black87, width: 3) 
              : Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: isAdaptive && isDark ? Colors.white.withOpacity(isSelected ? 0.3 : 0.0) : actualSwatchColor.withOpacity(isSelected ? 0.6 : 0.2), 
              blurRadius: isSelected ? 10 : 4, 
              spreadRadius: isSelected ? 1 : 0, 
            )
          ],
        ),
        child: isSelected ? Icon(Icons.check, color: isAdaptive ? Colors.redAccent : (_isLightColorForBg(displayColor) ? Colors.black87 : Colors.white), size: 20) : null,
      ),
    );
  }
}