import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/setlist_model.dart';
import '../../data/models/song_model.dart';
import '../../core/services/share_service.dart';
import '../../core/services/pdf_service.dart'; 
import 'setlist_screen.dart'; 
import '../song/song_reader_screen.dart';
import '../song/add_song_screen.dart';

const Map<String, Map<String, String>> _t = {
  'emptyList': {'tr': 'Liste Bomboş', 'en': 'List is Empty', 'de': 'Liste ist Leer'},
  'emptySub': {'tr': 'Repertuvarından parça ekle\nveya yeni bir şarkı yaz.', 'en': 'Add tracks from your repertoire\nor write a new song.', 'de': 'Füge Titel aus deinem Repertoire hinzu\noder schreibe einen neuen Song.'},
  'edit': {'tr': 'DÜZENLE', 'en': 'EDIT', 'de': 'BEARBEITEN'},
  'delete': {'tr': 'SİL', 'en': 'DELETE', 'de': 'LÖSCHEN'},
  'share': {'tr': 'PAYLAŞ', 'en': 'SHARE', 'de': 'TEILEN'},
  'cancel': {'tr': 'İPTAL', 'en': 'CANCEL', 'de': 'ABBRECHEN'},
  'areYouSure': {'tr': 'Emin misin?', 'en': 'Are you sure?', 'de': 'Bist du sicher?'},
  'deleteWarning': {'tr': ' kalıcı olarak silinecek.', 'en': ' will be permanently deleted.', 'de': ' wird dauerhaft gelöscht.'},
  'searchHint': {'tr': 'Parça Ara...', 'en': 'Search Track...', 'de': 'Titel suchen...'},
  'shareOptions': {'tr': 'Paylaşım Seçenekleri', 'en': 'Share Options', 'de': 'Freigabeoptionen'},
  'shareFormat': {'tr': 'Hangi Formatta Paylaşılacak?', 'en': 'Choose Export Format', 'de': 'Exportformat wählen'},
  'gigvaultFormat': {'tr': 'GigVault Dosyası Olarak (.json)', 'en': 'As GigVault File (.json)', 'de': 'Als GigVault-Datei (.json)'},
  'pdfFormat': {'tr': 'PDF Dokümanı Olarak (.pdf)', 'en': 'As PDF Document (.pdf)', 'de': 'Als PDF-Dokument (.pdf)'},
  'shareAllWithDrawings': {'tr': 'Çizimler Dâhil Paylaş', 'en': 'Share With Drawings', 'de': 'Mit Zeichnungen teilen'},
  'shareAllTextOnly': {'tr': 'Sadece Metin (Akor/Söz)', 'en': 'Text Only (Chords/Lyrics)', 'de': 'Nur Text (Akkorde/Liedtexte)'},
  'shareSelectSongs': {'tr': 'Parça Seçerek Paylaş', 'en': 'Share Selected Songs', 'de': 'Ausgewählte Songs Teilen'},
  'selectSongsToShare': {'tr': 'Paylaşılacak Parçaları Seç', 'en': 'Select Songs to Share', 'de': 'Songs zum Teilen Auswählen'},
  'next': {'tr': 'İLERİ', 'en': 'NEXT', 'de': 'WEITER'},
  'transfer': {'tr': 'Başka Listeye Aktar', 'en': 'Transfer to Another List', 'de': 'In eine andere Liste übertragen'},
  'noOtherList': {'tr': 'Aktarılacak başka bir liste bulunamadı.', 'en': 'No other list found to transfer.', 'de': 'Keine andere Liste gefunden.'},
  'whichList': {'tr': 'Hangi Listeye Aktarılacak?', 'en': 'Which List to Transfer?', 'de': 'In welche Liste übertragen?'},
  'tracks': {'tr': 'Parça', 'en': 'Tracks', 'de': 'Titel'},
  'alreadyExists': {'tr': 'Bu parça seçtiğin listede zaten var!', 'en': 'This track is already in the list!', 'de': 'Dieser Titel ist bereits in der Liste!'},
  'copyOrMove': {'tr': 'Kopyala mı, Taşı mı?', 'en': 'Copy or Move?', 'de': 'Kopieren oder Verschieben?'},
  'copyMoveDesc': {'tr': 'KOPYALA: Bu listede kalır, diğerine de eklenir.\n\nTAŞI: Bu listeden silinir, sadece diğerine gider.', 'en': 'COPY: Stays here, added to other.\n\nMOVE: Removed from here, goes to other.', 'de': 'KOPIEREN: Bleibt hier, wird hinzugefügt.\n\nVERSCHIEBEN: Wird entfernt, geht zur anderen.'},
  'copy': {'tr': 'KOPYALA', 'en': 'COPY', 'de': 'KOPIEREN'},
  'move': {'tr': 'TAŞI', 'en': 'MOVE', 'de': 'VERSCHIEBEN'},
  'copied': {'tr': 'Kopyalandı!', 'en': 'Copied!', 'de': 'Kopiert!'},
  'moved': {'tr': 'Başarıyla Taşındı!', 'en': 'Moved Successfully!', 'de': 'Erfolgreich verschoben!'},
};

class SetlistDetailScreen extends ConsumerStatefulWidget {
  final SetlistModel setlist;
  final String? initialSearchQuery; 

  const SetlistDetailScreen({super.key, required this.setlist, this.initialSearchQuery});

  @override
  ConsumerState<SetlistDetailScreen> createState() => _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  bool _isSearching = false;
  late TextEditingController _searchController;
  String _searchQuery = '';
  
  final GlobalKey _matchKey = GlobalKey();
  String _lastScrolledQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _isSearching = _searchQuery.isNotEmpty;
    _searchController = TextEditingController(text: _searchQuery);
  }

  String getText(String key, String lang) => _t[key]?[lang] ?? _t[key]?['en'] ?? key;

  Color _getColorFromString(String colorString) {
    switch (colorString) {
      case 'red': return const Color(0xFFFF0033); 
      case 'orange': return const Color(0xFFFF6600); 
      case 'yellow': return Colors.yellowAccent;
      case 'green': return const Color(0xFF39FF14); 
      case 'cyan': return Colors.cyanAccent;
      case 'blue': return Colors.blueAccent;
      case 'nightBlue': return const Color(0xFF3949AB); 
      case 'purple': return const Color(0xFF9D00FF); 
      case 'magenta': return const Color(0xFFFF00FF); 
      case 'pink': return const Color(0xFFFF1493); 
      case 'adaptive': 
      case 'white':
      case 'black':
        return Colors.transparent; 
      default: return const Color(0xFFFF0033); 
    }
  }

  Color _getAdaptedThemeColor(Color originalColor, bool isDark) {
    if (originalColor == Colors.transparent || originalColor == Colors.black || originalColor == Colors.white || originalColor == Colors.black87 || originalColor == Colors.white70) {
      return isDark ? Colors.white : Colors.black87;
    }
    if (!isDark) {
      if (originalColor == Colors.yellowAccent) return Colors.orange.shade700;
      if (originalColor == Colors.cyanAccent) return Colors.cyan.shade800;
      if (originalColor == const Color(0xFF39FF14)) return Colors.green.shade800;
    }
    return originalColor;
  }

  bool _isLightColorForBg(Color color) {
    if (color == Colors.transparent) return false;
    return color.computeLuminance() > 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final isFilled = ref.watch(filledCardsProvider); 
    final lang = ref.watch(appLanguageProvider); 
    
    final bgColor = isDark ? Colors.black : const Color(0xFFF0F0F3);
    final defaultTextColor = isDark ? Colors.white : Colors.black87;
    
    Color baseSetlistColor = _getColorFromString(widget.setlist.themeColor);
    Color uiThemeColor = _getAdaptedThemeColor(baseSetlistColor, isDark);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: uiThemeColor), 
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.montserrat(color: defaultTextColor, fontSize: 18),
                cursorColor: uiThemeColor,
                decoration: InputDecoration(
                  hintText: getText('searchHint', lang),
                  hintStyle: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
              )
            : Text(
                widget.setlist.title.toUpperCase(),
                style: GoogleFonts.bebasNeue(letterSpacing: 2.0, color: uiThemeColor, fontSize: 26),
              ),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, size: 26, color: uiThemeColor),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                  _lastScrolledQuery = ''; 
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.ios_share, size: 24, color: uiThemeColor),
              onPressed: () {
                final songsBox = Hive.box<SongModel>('songs');
                final allSongs = widget.setlist.songIds.map((id) => songsBox.get(id)).whereType<SongModel>().toList();
                _showExportFormatDialog(context, allSongs, isDark, uiThemeColor, lang, widget.setlist.title, true);
              },
            ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<SongModel>('songs').listenable(),
        builder: (context, Box<SongModel> songsBox, _) {
          
          final setlistSongs = widget.setlist.songIds
              .map((id) => songsBox.get(id))
              .where((song) => song != null)
              .cast<SongModel>()
              .toList();

          if (setlistSongs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_music_outlined, size: 60, color: uiThemeColor.withOpacity(0.5)),
                  const SizedBox(height: 24),
                  Text(getText('emptyList', lang), style: GoogleFonts.montserrat(color: defaultTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(getText('emptySub', lang), textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16)),
                ],
              ),
            );
          }

          List<Widget> songCards = [];
          bool foundMatch = false;

          for (int i = 0; i < setlistSongs.length; i++) {
            final song = setlistSongs[i];
            
            bool isMatch = _searchQuery.isNotEmpty && song.title.toLowerCase().contains(_searchQuery);
            
            Key? itemKey;
            if (isMatch && !foundMatch) {
              itemKey = _matchKey; 
              foundMatch = true;
              
              if (_lastScrolledQuery != _searchQuery) {
                _lastScrolledQuery = _searchQuery;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_matchKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _matchKey.currentContext!,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                      alignment: 0.2, 
                    );
                  }
                });
              }
            }

            Color baseSongColor = _getColorFromString(song.chordColor);
            Color uiSongColor = _getAdaptedThemeColor(baseSongColor, isDark);

            Color cardBgColor = isFilled ? uiSongColor : (isDark ? const Color(0xFF161616) : Colors.white);
            Color titleColor = isFilled ? (_isLightColorForBg(uiSongColor) ? Colors.black87 : Colors.white) : defaultTextColor;
            Color trailingColor = isFilled ? titleColor.withOpacity(0.7) : uiSongColor.withOpacity(0.5);
            
            Color avatarBg = isFilled ? (isDark ? Colors.black26 : Colors.white54) : uiSongColor.withOpacity(0.2);
            Color indexColor = isFilled ? titleColor : uiSongColor;

            songCards.add(
              ReorderableDelayedDragStartListener(
                key: ValueKey(song.id),
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    key: itemKey, 
                    color: isMatch ? (isDark ? Colors.grey.shade900 : Colors.amber.shade50) : cardBgColor,
                    margin: EdgeInsets.zero, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isMatch 
                        ? BorderSide(color: isDark ? Colors.amberAccent : Colors.orange, width: 3.0) 
                        : BorderSide(color: isFilled ? Colors.transparent : uiSongColor.withOpacity(0.3), width: 1.5),
                    ),
                    elevation: isMatch ? 8 : 1, 
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: avatarBg,
                        child: Text('${i + 1}', style: TextStyle(color: indexColor, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(song.title, style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w600)),
                      
                      trailing: IconButton(
                        icon: Icon(Icons.more_vert, color: trailingColor),
                        onPressed: () {
                          _showSongOptionsPanel(context, song, songsBox, isDark, uiThemeColor, lang);
                        },
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => SongReaderScreen(song: song)));
                      },
                    ),
                  ),
                ),
              )
            );
          }

          return ReorderableListView(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100), 
            buildDefaultDragHandles: false, 
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final String item = widget.setlist.songIds.removeAt(oldIndex);
                widget.setlist.songIds.insert(newIndex, item);
                widget.setlist.save(); 
              });
            },
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
              return Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: uiThemeColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)
                    ]
                  ),
                  child: child,
                ),
              );
            },
            children: songCards,
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: uiThemeColor.withOpacity(0.25), 
              blurRadius: 12, 
              spreadRadius: 0, 
              offset: const Offset(0, 4)
            )
          ]
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => AddSongScreen(setlist: widget.setlist)));
          },
          backgroundColor: uiThemeColor,
          elevation: 0,
          child: Icon(Icons.add, color: _isLightColorForBg(uiThemeColor) ? Colors.black87 : Colors.white, size: 36),
        ),
      ),
    );
  }

  void _showExportFormatDialog(BuildContext context, List<SongModel> songs, bool isDark, Color themeColor, String lang, String exportTitle, bool isFullSetlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (formatCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(getText('shareFormat', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                ListTile(
                  leading: const Icon(Icons.data_object, color: Colors.blueAccent, size: 28),
                  title: Text(getText('gigvaultFormat', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                  subtitle: Text("Uygulama içine direkt aktarılabilir", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(formatCtx);
                    _showDrawingChoiceDialog(context, songs, isDark, themeColor, lang, exportTitle, 'gigvault', isFullSetlist: isFullSetlist);
                  },
                ),
                Divider(color: isDark ? Colors.white24 : Colors.black12),
                
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
                  title: Text(getText('pdfFormat', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                  subtitle: Text("Yazdırılabilir veya her cihazda açılabilir", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(formatCtx);
                    _showDrawingChoiceDialog(context, songs, isDark, themeColor, lang, exportTitle, 'pdf', isFullSetlist: isFullSetlist);
                  },
                ),
                
                if (isFullSetlist) ...[
                  Divider(color: isDark ? Colors.white24 : Colors.black12),
                  ListTile(
                    leading: const Icon(Icons.checklist, color: Colors.green, size: 28),
                    title: Text(getText('shareSelectSongs', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(formatCtx);
                      _showMultiSelectDialog(context, themeColor, isDark, lang);
                    },
                  ),
                ]
              ],
            ),
          ),
        );
      }
    );
  }

  void _showDrawingChoiceDialog(BuildContext context, List<SongModel> songs, bool isDark, Color themeColor, String lang, String exportTitle, String exportFormat, {bool isFullSetlist = false}) {
    // SİHİRLİ SATIR: Mesajcıyı menü kapanmadan GÜVENLİ bir şekilde hafızaya alıyoruz
    final safeMessenger = ScaffoldMessenger.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(getText('shareOptions', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              ListTile(
                leading: Icon(Icons.brush, color: themeColor),
                title: Text(getText('shareAllWithDrawings', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () async {
                  Navigator.pop(sheetCtx); 
                  
                  if (exportFormat == 'pdf') {
                    safeMessenger.showSnackBar(const SnackBar(
                      content: Text('PDF Hazırlanıyor... Lütfen bekleyin.'), 
                      duration: Duration(seconds: 3)
                    ));
                    
                    String result = await PdfService.exportToPdf(exportTitle: exportTitle, songs: songs, includeDrawings: true);
                    
                    if (result != "OK") {
                      safeMessenger.showSnackBar(SnackBar(content: Text(result), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 6)));
                    }
                  } else {
                    ShareService.exportData(exportTitle: exportTitle, songs: songs, setlistContext: isFullSetlist ? widget.setlist : null, includeDrawings: true);
                  }
                },
              ),
              
              ListTile(
                leading: Icon(Icons.text_fields, color: themeColor),
                title: Text(getText('shareAllTextOnly', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () async {
                  Navigator.pop(sheetCtx); 
                  
                  if (exportFormat == 'pdf') {
                    safeMessenger.showSnackBar(const SnackBar(
                      content: Text('PDF Hazırlanıyor... Lütfen bekleyin.'), 
                      duration: Duration(seconds: 3)
                    ));
                    
                    String result = await PdfService.exportToPdf(exportTitle: exportTitle, songs: songs, includeDrawings: false);
                    
                    if (result != "OK") {
                      safeMessenger.showSnackBar(SnackBar(content: Text(result), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 6)));
                    }
                  } else {
                    ShareService.exportData(exportTitle: exportTitle, songs: songs, setlistContext: isFullSetlist ? widget.setlist : null, includeDrawings: false);
                  }
                },
              ),
            ],
          ),
        ),
      )
    );
  }

  void _showMultiSelectDialog(BuildContext context, Color themeColor, bool isDark, String lang) {
    final songsBox = Hive.box<SongModel>('songs');
    final allSongs = widget.setlist.songIds.map((id) => songsBox.get(id)).whereType<SongModel>().toList();
    List<SongModel> selectedSongs = [];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              title: Text(getText('selectSongsToShare', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allSongs.length,
                  itemBuilder: (listCtx, index) {
                    final s = allSongs[index];
                    return CheckboxListTile(
                      activeColor: themeColor,
                      checkColor: _isLightColorForBg(themeColor) ? Colors.black87 : Colors.white,
                      title: Text(s.title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                      value: selectedSongs.contains(s),
                      onChanged: (bool? val) {
                        setState(() {
                          if (val == true) selectedSongs.add(s);
                          else selectedSongs.remove(s);
                        });
                      },
                    );
                  }
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(getText('cancel', lang), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                  onPressed: selectedSongs.isEmpty ? null : () {
                    Navigator.pop(dialogCtx);
                    _showExportFormatDialog(context, selectedSongs, isDark, themeColor, lang, "Seçili Parçalar", false);
                  },
                  child: Text(getText('next', lang), style: TextStyle(color: _isLightColorForBg(themeColor) ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showSongOptionsPanel(BuildContext context, SongModel song, Box<SongModel> box, bool isDark, Color themeColor, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(Icons.share, color: themeColor),
                  title: Text(getText('share', lang), style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  onTap: () {
                    Navigator.pop(sheetCtx); 
                    _showExportFormatDialog(context, [song], isDark, themeColor, lang, song.title, false);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: themeColor),
                  title: Text(getText('transfer', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showTransferSheet(context, song, widget.setlist, isDark, lang, themeColor);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: themeColor),
                  title: Text(getText('edit', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  onTap: () {
                    Navigator.pop(sheetCtx); 
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddSongScreen(setlist: widget.setlist, songToEdit: song)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text(getText('delete', lang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  onTap: () {
                    Navigator.pop(sheetCtx); 
                    _showDeleteConfirmation(context, song, isDark, lang); 
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showDeleteConfirmation(BuildContext context, SongModel song, bool isDark, String lang) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
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
          content: Text('"${song.title}"${getText('deleteWarning', lang)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(getText('cancel', lang), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
              onPressed: () {
                widget.setlist.songIds.remove(song.id);
                widget.setlist.save();
                song.delete();
                Navigator.pop(dialogCtx);
              },
              child: Text(getText('delete', lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
  
  void _showTransferSheet(BuildContext context, SongModel song, SetlistModel currentSetlist, bool isDark, String lang, Color themeColor) {
    final box = Hive.box<SetlistModel>('setlists');
    final otherSetlists = box.values.where((s) => s.id != currentSetlist.id).toList();

    if (otherSetlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getText('noOtherList', lang)), backgroundColor: Colors.orange),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(getText('whichList', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: otherSetlists.length,
                  itemBuilder: (listCtx, index) {
                    final target = otherSetlists[index];
                    return ListTile(
                      leading: Icon(Icons.queue_music, color: themeColor),
                      title: Text(target.title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text("${target.songIds.length} ${getText('tracks', lang)}", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _showCopyMoveDialog(context, song, currentSetlist, target, isDark, lang, themeColor);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

 void _showCopyMoveDialog(BuildContext context, SongModel song, SetlistModel currentSetlist, SetlistModel targetSetlist, bool isDark, String lang, Color themeColor) {
    if (targetSetlist.songIds.contains(song.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getText('alreadyExists', lang)), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // GÜVENLİK KİLİDİ: Mesajı basacak olan motoru, dialog açılmadan ÖNCE hafızaya alıyoruz.
    final mainMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(getText('copyOrMove', lang), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Text(
            getText('copyMoveDesc', lang),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () {
                targetSetlist.songIds.add(song.id);
                targetSetlist.save();
                
                Navigator.pop(dialogCtx); 
                
                mainMessenger.showSnackBar(SnackBar(content: Text(getText('copied', lang)), backgroundColor: Colors.green));
                if (mounted) setState(() {}); 
              },
              child: Text(getText('copy', lang), style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: themeColor),
              onPressed: () {
                targetSetlist.songIds.add(song.id);
                targetSetlist.save();
                
                currentSetlist.songIds.remove(song.id);
                currentSetlist.save();
                
                Navigator.pop(dialogCtx);
                
                mainMessenger.showSnackBar(SnackBar(content: Text(getText('moved', lang)), backgroundColor: Colors.green));
                if (mounted) setState(() {}); 
              },
              child: Text(getText('move', lang), style: TextStyle(color: _isLightColorForBg(themeColor) ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}