import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/setlist_model.dart';
import '../../data/models/song_model.dart';
import '../setlist/setlist_screen.dart'; 

class AddSongScreen extends ConsumerStatefulWidget {
  final SetlistModel setlist; 
  final SongModel? songToEdit;

  const AddSongScreen({super.key, required this.setlist, this.songToEdit});

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _uuid = const Uuid();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _selectedCardColor; 
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.songToEdit?.title ?? '');
    _contentController = TextEditingController(text: widget.songToEdit?.content ?? '');
    
    String initialColor = widget.songToEdit?.chordColor ?? 'adaptive';
    if (initialColor == 'white' || initialColor == 'black') initialColor = 'adaptive';
    _selectedCardColor = initialColor;
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
    
    Color baseSetlistColor = _getColorFromString(widget.setlist.themeColor);
    Color uiThemeColor = _getAdaptedThemeColor(baseSetlistColor, isDark);

    final isEditMode = widget.songToEdit != null;

    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : Colors.black87;
    final editorBgColor = isDark ? const Color(0xFF161616) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: uiThemeColor), 
        title: Text(
          isEditMode ? 'ŞARKIYI DÜZENLE' : 'YENİ ŞARKI', 
          style: GoogleFonts.bebasNeue(letterSpacing: 2.0, color: uiThemeColor, fontSize: 26) 
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                style: GoogleFonts.montserrat(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Şarkı Adı',
                  hintStyle: GoogleFonts.montserrat(color: textColor.withOpacity(0.5), fontSize: 20),
                  border: InputBorder.none,
                  errorText: _errorMessage,
                ),
                onChanged: (val) { if (_errorMessage != null) setState(() => _errorMessage = null); },
              ),
              const SizedBox(height: 16),
              
              // --- EKSİKSİZ TAM RENK PALETİ ---
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildChordColorOption('red', const Color(0xFFFF0033), isDark, uiThemeColor),
                    _buildChordColorOption('orange', const Color(0xFFFF6600), isDark, uiThemeColor),
                    _buildChordColorOption('yellow', Colors.yellowAccent, isDark, uiThemeColor),
                    _buildChordColorOption('green', const Color(0xFF39FF14), isDark, uiThemeColor),
                    _buildChordColorOption('cyan', Colors.cyanAccent, isDark, uiThemeColor),
                    _buildChordColorOption('blue', Colors.blueAccent, isDark, uiThemeColor),
                    _buildChordColorOption('nightBlue', const Color(0xFF0014A8), isDark, uiThemeColor),
                    _buildChordColorOption('purple', const Color(0xFF9D00FF), isDark, uiThemeColor),
                    _buildChordColorOption('magenta', const Color(0xFFFF00FF), isDark, uiThemeColor),
                    _buildChordColorOption('pink', const Color(0xFFFF1493), isDark, uiThemeColor),
                    _buildChordColorOption('adaptive', Colors.transparent, isDark, uiThemeColor, isAdaptive: true), 
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: editorBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: uiThemeColor.withOpacity(0.3)), 
                  ),
                  child: TextField(
                    controller: _contentController,
                    maxLines: null, expands: true, 
                    style: GoogleFonts.robotoMono(color: textColor, fontSize: 14.0, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'İnternetten kopyalayıp buraya yapıştır...'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: uiThemeColor, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () => _saveSong(),
                  child: Text(
                    isEditMode ? 'GÜNCELLE' : 'KASAYA EKLE', 
                    style: TextStyle(
                      color: _isLightColorForBg(uiThemeColor) ? Colors.black87 : Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveSong() {
    final title = _titleController.text.trim();
    final content = _contentController.text.replaceAll('\t', '    ');

    if (title.isEmpty || content.trim().isEmpty) {
      setState(() => _errorMessage = 'Başlık ve sözler boş olamaz!');
      return;
    }

    final songsBox = Hive.box<SongModel>('songs');
    if (widget.songToEdit != null) {
      widget.songToEdit!.title = title;
      widget.songToEdit!.content = content;
      widget.songToEdit!.chordColor = _selectedCardColor;
      widget.songToEdit!.save();
    } else {
      final newSong = SongModel(id: _uuid.v4(), title: title, content: content, transposeStep: 0, chordColor: _selectedCardColor);
      songsBox.put(newSong.id, newSong);
      widget.setlist.songIds.add(newSong.id);
      widget.setlist.save(); 
    }
    Navigator.pop(context);
  }

  Widget _buildChordColorOption(String colorName, Color color, bool isDark, Color uiThemeColor, {bool isAdaptive = false}) {
    bool isSelected = _selectedCardColor == colorName;
    Color displayColor = isAdaptive ? (isDark ? Colors.white : Colors.black87) : color;

    return GestureDetector(
      onTap: () => setState(() => _selectedCardColor = colorName),
      child: Container(
        margin: const EdgeInsets.only(right: 12), width: 36, height: 36,
        decoration: BoxDecoration(
          color: isAdaptive ? null : color, 
          gradient: isAdaptive ? const LinearGradient(
            colors: [Colors.black, Colors.white],
            stops: [0.5, 0.5],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          shape: BoxShape.circle, 
          border: Border.all(
            color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.grey.withOpacity(0.5), 
            width: isSelected ? 3 : 1
          )
        ),
        child: isSelected 
          ? Icon(
              Icons.check, 
              color: isAdaptive ? uiThemeColor : (_isLightColorForBg(displayColor) ? Colors.black87 : Colors.white), 
              size: 18,
              shadows: isAdaptive ? [Shadow(color: isDark ? Colors.black87 : Colors.white70, blurRadius: 4)] : null,
            ) 
          : null,
      ),
    );
  }
}