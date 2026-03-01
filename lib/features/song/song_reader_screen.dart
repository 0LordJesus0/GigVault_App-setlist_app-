import 'dart:ui';
import 'dart:convert'; 
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart'; 
import '../../data/models/song_model.dart';
import '../setlist/setlist_screen.dart'; 

final isFullColorProvider = StateProvider<bool>((ref) {
  return Hive.box('settings').get('isFullColor', defaultValue: false);
});

final globalChordColorProvider = StateProvider<Color>((ref) {
  final val = Hive.box('settings').get('chordColor', defaultValue: const Color(0xFFFF0033).value);
  return Color(val);
});

enum DrawingTool { pointer, pen, arrow, eraserPixel, eraserObject }

class TextNode {
  final String id;
  String text;
  String colorName;
  Offset position;
  double scale;
  double rotation;

  TextNode({
    required this.id,
    required this.text,
    required this.colorName,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'color': colorName,
    'x': position.dx,
    'y': position.dy,
    'scale': scale,
    'rotation': rotation,
  };

  factory TextNode.fromJson(Map<String, dynamic> json) => TextNode(
    id: json['id'] as String,
    text: json['text'] as String,
    colorName: json['color'] as String,
    position: Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble()),
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
  );
}

class StrokeData {
  final List<Offset> points;
  final String colorName;
  final double strokeWidth;
  final bool isArrow; 
  final bool isEraser; 

  StrokeData({
    required this.points, 
    required this.colorName, 
    required this.strokeWidth, 
    this.isArrow = false,
    this.isEraser = false,
  });

  Map<String, dynamic> toJson() => {
    'color': colorName,
    'width': strokeWidth,
    'isArrow': isArrow,
    'isEraser': isEraser,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
  };

  factory StrokeData.fromJson(Map<String, dynamic> json) {
    var pts = json['points'] as List;
    return StrokeData(
      colorName: json['color'] as String,
      strokeWidth: (json['width'] as num).toDouble(),
      isArrow: json['isArrow'] ?? false,
      isEraser: json['isEraser'] ?? false,
      points: pts.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList(),
    );
  }
}

class SongReaderScreen extends ConsumerStatefulWidget {
  final SongModel song;
  const SongReaderScreen({super.key, required this.song});
  
  @override
  ConsumerState<SongReaderScreen> createState() => _SongReaderScreenState();
}

class _SongReaderScreenState extends ConsumerState<SongReaderScreen> {
  late int _currentStep;
  bool _isFitToScreen = true; 

  bool _isDrawingMode = false;
  DrawingTool _currentTool = DrawingTool.pointer; 

  List<StrokeData> _strokes = [];
  List<Offset> _currentPoints = [];
  String _brushColorName = 'adaptive'; 
  double _brushSize = 3.0; 

  List<TextNode> _texts = [];
  TextNode? _activeTextNode; 
  double _baseScaleFactor = 1.0;
  double _baseRotation = 0.0;

  Offset? _fingerPosition;

  static const List<String> _notesSharps = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
  static const Map<String,int> _noteIndex = {
    'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,
    'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11
  };

  @override
  void initState() {
    super.initState();
    _currentStep = widget.song.transposeStep; 
    _loadCanvasData(); 
  }

  Future<void> _loadCanvasData() async {
    var box = await Hive.openBox<String>('drawings_box');
    String? drawStr = box.get(widget.song.id); 
    String? textStr = box.get('${widget.song.id}_texts'); 
    
    setState(() {
      if (drawStr != null) {
        List decoded = jsonDecode(drawStr);
        _strokes = decoded.map((s) => StrokeData.fromJson(s as Map<String, dynamic>)).toList();
      }
      if (textStr != null) {
        List decoded = jsonDecode(textStr);
        _texts = decoded.map((t) => TextNode.fromJson(t as Map<String, dynamic>)).toList();
      }
    });
  }

  Future<void> _saveDrawings() async {
    var box = await Hive.openBox<String>('drawings_box');
    String jsonStr = jsonEncode(_strokes.map((s) => s.toJson()).toList());
    await box.put(widget.song.id, jsonStr); 
  }

  Future<void> _saveTexts() async {
    var box = await Hive.openBox<String>('drawings_box');
    String jsonStr = jsonEncode(_texts.map((t) => t.toJson()).toList());
    await box.put('${widget.song.id}_texts', jsonStr);
  }

  String _transposeChord(String chord) {
    if (_currentStep == 0) return chord;
    final m = RegExp(r'^([A-G][#b]?)(.*)').firstMatch(chord);
    if (m == null) return chord;
    final root = m.group(1)!, suf = m.group(2)!;
    int idx = _noteIndex[root] ?? 0;
    int ni  = (idx + _currentStep) % 12;
    if (ni < 0) ni += 12;
    return _notesSharps[ni] + suf;
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

  Color _getColorFromName(String name, bool isDark) {
    switch(name) {
      case 'red': return Colors.redAccent;
      case 'blue': return Colors.blueAccent;
      case 'green': return Colors.greenAccent;
      case 'yellow': return Colors.yellowAccent;
      case 'adaptive': return isDark ? Colors.white : Colors.black87;
      default: return Colors.redAccent;
    }
  }

  String _getToolName(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pointer: return 'İşaretçi (Kaydır)';
      case DrawingTool.pen: return 'Serbest Kalem';
      case DrawingTool.arrow: return 'Ok Çizimi';
      case DrawingTool.eraserPixel: return 'Piksel Silgisi';
      case DrawingTool.eraserObject: return 'Obje Silgisi';
    }
  }

  void _performErase(Offset local) {
    double cursorRadius = 20.0 + _brushSize;
    bool changed = false;

    _strokes.removeWhere((stroke) {
      if (stroke.isEraser) return false; 

      for (var p in stroke.points) {
         if ((p - local).distance < cursorRadius) {
            changed = true;
            return true;
         }
      }
      return false;
    });

    _texts.removeWhere((node) {
      Rect textBounds = Rect.fromLTWH(
        node.position.dx, 
        node.position.dy, 
        120 * node.scale, 
        60 * node.scale
      ).inflate(cursorRadius + 20.0); 
      
      if (textBounds.contains(local)) {
        changed = true;
        if (_activeTextNode == node) _activeTextNode = null;
        return true;
      }
      return false;
    });

    if (changed) {
      _saveDrawings();
      _saveTexts();
    }
  }

  TextSpan _buildText(String text, Color chordColor, Color lyricColor) {
    final rx = RegExp(
      r'(?<=\s|\[|^)' +
      r'([A-G](?:#|b)?(?:m|maj|min|dim|aug|sus|add|ø|o)?(?:maj7|m7|7|6|9|11|13|2|4)?)' +
      r'(?=\s|\]|$)'
    );

    final spans = <TextSpan>[];
    String cleanText = text.replaceAll('\r', '');
    
    for (var line in cleanText.split('\n')) {
      int last = 0;
      for (final m in rx.allMatches(line)) {
        if (m.start > last) spans.add(TextSpan(text: line.substring(last, m.start)));
        
        spans.add(TextSpan(
          text: _transposeChord(m.group(1)!),
          style: TextStyle(color: chordColor, fontWeight: FontWeight.bold),
        ));
        last = m.end;
      }
      if (last < line.length) spans.add(TextSpan(text: line.substring(last)));
      spans.add(const TextSpan(text: '\n'));
    }
    
    return TextSpan(
      children: spans, 
      style: TextStyle(color: lyricColor, fontSize: 16.0, height: 1.6)
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final isFullColor = ref.watch(isFullColorProvider); 
    final globalChordColor = ref.watch(globalChordColorProvider); 
    
    final rawAppThemeColor = ref.watch(appThemeColorProvider);
    
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : Colors.black87;

    Color uiThemeColor = rawAppThemeColor == Colors.transparent 
        ? (isDark ? Colors.white : Colors.black87) 
        : rawAppThemeColor;
        
    Color adaptedChordColor = _getAdaptedThemeColor(globalChordColor, isDark);

    Color appBarBg = isDark ? const Color(0xFF121212) : Colors.white;
    Color uiContentColor = uiThemeColor; 

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg, 
        elevation: 0,
        iconTheme: IconThemeData(color: uiContentColor), 
        title: Text(
          widget.song.title, 
          style: GoogleFonts.montserrat(color: uiContentColor, fontWeight: FontWeight.bold, fontSize: 20) 
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.brush, color: _isDrawingMode ? (isFullColor ? uiContentColor.withOpacity(0.5) : Colors.orangeAccent) : uiContentColor, size: 24),
            onPressed: () {
              setState(() {
                _isDrawingMode = !_isDrawingMode;
                _activeTextNode = null; 
                if (_isDrawingMode) _currentTool = DrawingTool.pointer; 
              });
            }
          ),
          IconButton(
            icon: Icon(Icons.edit_note, color: uiContentColor, size: 28),
            onPressed: () => _showQuickEditDialog(context, isDark, uiThemeColor, textColor),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: uiContentColor), 
            onPressed: () => _showReaderSettings(context, isDark, textColor, globalChordColor, uiThemeColor),
          )
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isDrawingMode ? 160 : 54), 
          child: Container(
            height: _isDrawingMode ? 160 : 54,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: appBarBg, 
              border: Border(bottom: BorderSide(color: isFullColor ? Colors.transparent : uiThemeColor.withOpacity(0.2), width: 1.5))
            ),
            child: _isDrawingMode 
                ? _buildDrawingToolbar(uiContentColor, isDark, isFullColor) 
                : _buildTransposeToolbar(uiContentColor, isFullColor),
          ),
        ),
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: _isFitToScreen 
            ? _buildFittedView(adaptedChordColor, textColor, isDark, uiThemeColor)
            : _buildInteractiveView(adaptedChordColor, textColor, isDark, uiThemeColor), 
        ),
      ),
    );
  }

  Widget _buildTransposeToolbar(Color uiColor, bool isFullColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isFitToScreen = !_isFitToScreen),
          child: Container(
            width: 30, height: 30, 
            decoration: BoxDecoration(
              color: isFullColor ? uiColor.withOpacity(0.2) : uiColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isFullColor ? uiColor.withOpacity(0.5) : uiColor.withOpacity(0.3)),
            ),
            child: Icon(_isFitToScreen ? Icons.aspect_ratio : Icons.zoom_out_map, color: uiColor, size: 18),
          ),
        ),
        Row(
          children: [
            Text('TRANSPOZE', style: GoogleFonts.montserrat(color: isFullColor ? uiColor.withOpacity(0.9) : uiColor.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(width: 8),
            _buildMiniButton(Icons.remove, () {
              if (_currentStep > -11) {
                setState(() => _currentStep--);
                widget.song.transposeStep = _currentStep;
                widget.song.save(); 
              }
            }, uiColor, isFullColor),
            Container(
              width: 32, alignment: Alignment.center,
              child: Text(_currentStep > 0 ? '+$_currentStep' : '$_currentStep', style: TextStyle(color: uiColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            _buildMiniButton(Icons.add, () {
              if (_currentStep < 11) {
                setState(() => _currentStep++);
                widget.song.transposeStep = _currentStep;
                widget.song.save(); 
              }
            }, uiColor, isFullColor),
          ],
        ),
      ],
    );
  }

  Widget _buildDrawingToolbar(Color uiColor, bool isDark, bool isFullColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildToolButton(DrawingTool.pointer, Icons.pan_tool_alt_outlined, uiColor, isFullColor), 
                const SizedBox(width: 6),
                _buildToolButton(DrawingTool.pen, Icons.edit, uiColor, isFullColor),
                const SizedBox(width: 6),
                _buildToolButton(DrawingTool.arrow, Icons.call_made, uiColor, isFullColor), 
                const SizedBox(width: 6),
                _buildToolButton(DrawingTool.eraserPixel, Icons.cleaning_services, uiColor, isFullColor), 
                const SizedBox(width: 6),
                _buildToolButton(DrawingTool.eraserObject, Icons.backspace_outlined, uiColor, isFullColor), 
              ],
            ),
            if (_activeTextNode != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _texts.remove(_activeTextNode);
                    _activeTextNode = null;
                  });
                  _saveTexts();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                ),
              )
            else
              Text(_getToolName(_currentTool), style: TextStyle(color: uiColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        
        // MATEMATİKSEL OLARAK FIRÇA ÇAPINA (%100) EŞİTLENMİŞ NOKTA
        Row(
          children: [
            Icon(Icons.circle, size: 6, color: uiColor.withOpacity(0.7)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4.0,
                  // Yarıçap = Fırça Kalınlığı / 2 
                  // math.max(4.0, ...) ile 8 pikselden daha ufak olup kaybolması engellendi.
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: math.max(4.0, _brushSize / 2), 
                    pressedElevation: 6.0,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: math.max(16.0, (_brushSize / 2) + 12.0),
                  ),
                ),
                child: Slider(
                  value: _brushSize,
                  min: 1.0,
                  max: 30.0,
                  activeColor: uiColor,
                  inactiveColor: uiColor.withOpacity(0.2),
                  onChanged: (val) => setState(() => _brushSize = val),
                ),
              ),
            ),
            Icon(Icons.circle, size: 24, color: uiColor.withOpacity(0.7)),
            const SizedBox(width: 12),
            SizedBox(
              width: 24,
              child: Text(_brushSize.toInt().toString(), style: TextStyle(color: uiColor, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.text_fields, color: uiColor, size: 24),
              onPressed: () => _showAddTextDialog(isDark, uiColor), 
            ),
          ],
        ),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDrawingColorDot('red', Colors.redAccent, isDark),
                    _buildDrawingColorDot('blue', Colors.blueAccent, isDark),
                    _buildDrawingColorDot('green', Colors.greenAccent, isDark),
                    _buildDrawingColorDot('yellow', Colors.yellowAccent, isDark),
                    _buildDrawingColorDot('adaptive', Colors.transparent, isDark, isAdaptive: true), 
                  ],
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.undo, color: _strokes.isEmpty ? uiColor.withOpacity(0.3) : uiColor, size: 22),
                  onPressed: _strokes.isEmpty ? null : () {
                    setState(() => _strokes.removeLast());
                    _saveDrawings(); 
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.delete_sweep, color: Colors.redAccent.withOpacity(0.8), size: 22),
                  onPressed: () => _showClearAllConfirmation(isDark), 
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() {
                    _isDrawingMode = false;
                    _activeTextNode = null;
                  }),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isFullColor ? uiColor.withOpacity(0.2) : uiColor, 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Icon(
                      Icons.check, 
                      color: isFullColor ? uiColor : (_isLightColorForBg(uiColor) ? Colors.black87 : Colors.white), 
                      size: 20
                    ),
                  ),
                )
              ],
            ),
          ],
        )
      ],
    );
  }

  Widget _buildToolButton(DrawingTool tool, IconData icon, Color uiColor, bool isFullColor) {
    bool isSelected = _currentTool == tool;
    return GestureDetector(
      onTap: () => setState(() {
        _currentTool = tool;
        _activeTextNode = null; 
      }),
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: isSelected ? uiColor.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? uiColor : uiColor.withOpacity(0.3)),
        ),
        child: Icon(icon, color: isSelected ? uiColor : uiColor.withOpacity(0.6), size: 18),
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, VoidCallback onTap, Color uiColor, bool isFullColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28, 
        decoration: BoxDecoration(
          color: isFullColor ? uiColor.withOpacity(0.2) : uiColor.withOpacity(0.08), 
          borderRadius: BorderRadius.circular(6), 
          border: Border.all(color: isFullColor ? uiColor.withOpacity(0.5) : uiColor.withOpacity(0.3))
        ),
        child: Icon(icon, color: uiColor, size: 16),
      ),
    );
  }

  Widget _buildDrawingColorDot(String colorName, Color color, bool isDark, {bool isAdaptive = false}) {
    bool isSelected = _brushColorName == colorName;
    return GestureDetector(
      onTap: () => setState(() {
        _brushColorName = colorName;
        if (_activeTextNode != null) {
          _activeTextNode!.colorName = colorName;
          _saveTexts();
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: isAdaptive ? null : color,
          gradient: isAdaptive ? const LinearGradient(
            colors: [Colors.black, Colors.white],
            stops: [0.5, 0.5],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.grey : Colors.transparent, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 4)] : [],
        ),
      ),
    );
  }

  Widget _buildStackContent(Color chordColor, Color textColor, bool isDark, Color uiThemeColor) {
    double cursorRadius = 20.0 + _brushSize;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isDrawingMode ? () {
        if (_activeTextNode != null) {
          setState(() => _activeTextNode = null);
        }
      } : null,
      onScaleStart: (_isDrawingMode && (_currentTool != DrawingTool.pointer || _activeTextNode != null)) 
        ? (details) {
            if (_activeTextNode != null) {
              _baseScaleFactor = _activeTextNode!.scale;
              _baseRotation = _activeTextNode!.rotation;
            } else {
              setState(() {
                _fingerPosition = details.localFocalPoint; 
                if (_currentTool == DrawingTool.eraserObject) {
                  _performErase(details.localFocalPoint);
                } else if (_currentTool != DrawingTool.eraserObject) {
                  _currentPoints = [details.localFocalPoint];
                }
              });
            }
          } 
        : null,
      onScaleUpdate: (_isDrawingMode && (_currentTool != DrawingTool.pointer || _activeTextNode != null)) 
        ? (details) {
            if (_activeTextNode != null) {
              setState(() {
                _activeTextNode!.position += details.focalPointDelta;
                _activeTextNode!.scale = _baseScaleFactor * details.scale;
                _activeTextNode!.rotation = _baseRotation + details.rotation;
              });
            } else {
              setState(() {
                _fingerPosition = details.localFocalPoint; 
                Offset local = details.localFocalPoint;

                if (_currentTool == DrawingTool.eraserObject) {
                  _performErase(local);
                } else {
                  _currentPoints.add(local);
                }
              });
            }
          } 
        : null,
      onScaleEnd: (_isDrawingMode && (_currentTool != DrawingTool.pointer || _activeTextNode != null)) 
        ? (details) {
            if (_activeTextNode != null) {
              _saveTexts(); 
            } else {
              setState(() => _fingerPosition = null); 
              if (_currentTool != DrawingTool.eraserObject && _currentPoints.isNotEmpty) {
                setState(() {
                  _strokes.add(StrokeData(
                    points: List.from(_currentPoints), 
                    colorName: _brushColorName, 
                    strokeWidth: _brushSize,
                    isArrow: _currentTool == DrawingTool.arrow, 
                    isEraser: _currentTool == DrawingTool.eraserPixel, 
                  ));
                  _currentPoints = [];
                });
                _saveDrawings(); 
              }
            }
          } 
        : null,
      
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 600.0, right: 100.0),
              child: RichText(
                softWrap: false, 
                text: _buildText(widget.song.content, chordColor, textColor.withOpacity(0.9)),
              ),
            ),
            
            Positioned.fill(
              child: CustomPaint(
                painter: DrawingPainter(
                  strokes: _strokes, 
                  currentPoints: _currentPoints, 
                  currentColorName: _brushColorName, 
                  currentStrokeWidth: _brushSize, 
                  isDark: isDark,
                  currentTool: _currentTool,
                ),
              ),
            ),

            ..._texts.map((node) {
              bool isActive = _isDrawingMode && _activeTextNode == node;
              bool isPointer = _currentTool == DrawingTool.pointer;
              bool isEraserObj = _currentTool == DrawingTool.eraserObject;

              return Positioned(
                left: node.position.dx,
                top: node.position.dy,
                child: IgnorePointer(
                  ignoring: !_isDrawingMode || !(isPointer || isEraserObj || isActive),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isEraserObj) {
                        setState(() {
                          _texts.remove(node);
                          if (_activeTextNode == node) _activeTextNode = null;
                        });
                        _saveTexts();
                        return;
                      }

                      if (isPointer && _activeTextNode != node) {
                        setState(() => _activeTextNode = node);
                        
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Düzenlemek için çift tıkla.\nSilmek için 'Obje Silgisi'ni veya çöp kutusunu kullan.",
                                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: isDark ? Colors.grey.shade900 : Colors.black87,
                            duration: const Duration(seconds: 4),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                          ),
                        );
                      }
                    },
                    onDoubleTap: isPointer ? () {
                      _showAddTextDialog(isDark, uiThemeColor, existingNode: node);
                    } : null,
                    
                    onScaleStart: isPointer ? (details) {
                      if (_activeTextNode != node) {
                        setState(() => _activeTextNode = node);
                      }
                      _baseScaleFactor = node.scale;
                      _baseRotation = node.rotation;
                    } : null,
                    onScaleUpdate: isPointer ? (details) {
                      if (_activeTextNode == node) {
                        setState(() {
                          node.position += details.focalPointDelta;
                          node.scale = _baseScaleFactor * details.scale;
                          node.rotation = _baseRotation + details.rotation;
                        });
                      }
                    } : null,
                    onScaleEnd: isPointer ? (details) {
                      if (_activeTextNode == node) _saveTexts();
                    } : null,
                    
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(node.scale)
                        ..rotateZ(node.rotation),
                      child: CustomPaint(
                        painter: isActive ? DashedBorderPainter(color: isDark ? Colors.white70 : Colors.black54) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: Colors.transparent, 
                          child: Text(
                            node.text,
                            style: TextStyle(
                              color: _getColorFromName(node.colorName, isDark),
                              fontSize: 24, 
                              fontWeight: FontWeight.w900, 
                              shadows: isActive ? [] : [Shadow(color: isDark ? Colors.black87 : Colors.white70, blurRadius: 4)], 
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),

            if (_fingerPosition != null && _isDrawingMode && _activeTextNode == null && _currentTool != DrawingTool.pointer)
              Positioned(
                left: _fingerPosition!.dx - cursorRadius,
                top: _fingerPosition!.dy - cursorRadius,
                child: IgnorePointer( 
                  child: Container(
                    width: cursorRadius * 2,
                    height: cursorRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white70 : Colors.black87, 
                        width: 1.5
                      ),
                      color: (_currentTool == DrawingTool.eraserPixel || _currentTool == DrawingTool.eraserObject)
                          ? Colors.redAccent.withOpacity(0.2) 
                          : _getColorFromName(_brushColorName, isDark).withOpacity(0.3), 
                    ),
                    child: Center(
                      child: Container(
                        width: 4, height: 4, 
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          shape: BoxShape.circle
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFittedView(Color chordColor, Color textColor, bool isDark, Color uiThemeColor) {
    bool canScroll = !_isDrawingMode || _currentTool == DrawingTool.pointer;
    
    return SingleChildScrollView(
      physics: canScroll ? null : const NeverScrollableScrollPhysics(), 
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width - 32,
        child: FittedBox(
          fit: BoxFit.scaleDown, 
          alignment: Alignment.centerLeft,
          child: _buildStackContent(chordColor, textColor, isDark, uiThemeColor), 
        ),
      ),
    );
  }

  Widget _buildInteractiveView(Color chordColor, Color textColor, bool isDark, Color uiThemeColor) {
    bool canPanScale = !_isDrawingMode || _currentTool == DrawingTool.pointer;

    return InteractiveViewer(
      panEnabled: canPanScale,   
      scaleEnabled: canPanScale, 
      clipBehavior: Clip.none,
      minScale: 0.5,
      maxScale: 4.0, 
      constrained: false, 
      boundaryMargin: const EdgeInsets.all(80.0), 
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _buildStackContent(chordColor, textColor, isDark, uiThemeColor), 
      ),
    );
  }

  void _showClearAllConfirmation(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        title: Text('Tahtayı Temizle', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('Tüm çizimleri ve notları silmek istediğine emin misin?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('İPTAL', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _strokes.clear();
                _texts.clear();
                _activeTextNode = null;
              });
              _saveDrawings();
              _saveTexts();
              Navigator.pop(context);
            },
            child: const Text('TEMİZLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddTextDialog(bool isDark, Color uiColor, {TextNode? existingNode}) {
    TextEditingController ctrl = TextEditingController(text: existingNode?.text ?? '');
    String selectedColor = existingNode?.colorName ?? _brushColorName;
    Color btnTextColor = _isLightColorForBg(uiColor) ? Colors.black87 : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              title: Text(
                existingNode == null ? 'Not Ekle' : 'Notu Düzenle', 
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Metin...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: uiColor)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildDialogColorDot('red', Colors.redAccent, selectedColor, isDark, (c) => setDialogState(() => selectedColor = c)),
                      _buildDialogColorDot('blue', Colors.blueAccent, selectedColor, isDark, (c) => setDialogState(() => selectedColor = c)),
                      _buildDialogColorDot('green', Colors.greenAccent, selectedColor, isDark, (c) => setDialogState(() => selectedColor = c)),
                      _buildDialogColorDot('yellow', Colors.yellowAccent, selectedColor, isDark, (c) => setDialogState(() => selectedColor = c)),
                      _buildDialogColorDot('adaptive', Colors.transparent, selectedColor, isDark, (c) => setDialogState(() => selectedColor = c), isAdaptive: true),
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text('İPTAL', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: uiColor),
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      if (existingNode != null) {
                        existingNode.text = ctrl.text.trim();
                        existingNode.colorName = selectedColor;
                        setState(() => _activeTextNode = existingNode);
                      } else {
                        var newNode = TextNode(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          text: ctrl.text.trim(),
                          colorName: selectedColor,
                          position: Offset(
                            MediaQuery.of(context).size.width / 2 - 80, 
                            MediaQuery.of(context).size.height / 3, 
                          ), 
                        );
                        setState(() {
                          _texts.add(newNode);
                          _activeTextNode = newNode; 
                          _brushColorName = selectedColor; 
                        });
                      }
                      _saveTexts();
                    }
                    Navigator.pop(context);
                  },
                  child: Text('KAYDET', style: TextStyle(color: btnTextColor, fontWeight: FontWeight.bold)),
                )
              ]
            );
          }
        );
      }
    );
  }

  Widget _buildDialogColorDot(String colorName, Color color, String selectedColor, bool isDark, Function(String) onSelect, {bool isAdaptive = false}) {
    bool isSelected = selectedColor == colorName;
    Color displayColor = isAdaptive ? (isDark ? Colors.white : Colors.black87) : color;

    return GestureDetector(
      onTap: () => onSelect(colorName),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: isAdaptive ? null : color, 
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
              color: isAdaptive && isDark ? Colors.white.withOpacity(isSelected ? 0.3 : 0.0) : displayColor.withOpacity(isSelected ? 0.8 : 0.3),
              blurRadius: isSelected ? 8 : 4,
              spreadRadius: isSelected ? 2 : 0,
            )
          ],
        ),
        child: isSelected ? Icon(Icons.check, color: isAdaptive ? Colors.redAccent : (_isLightColorForBg(displayColor) ? Colors.black87 : Colors.white), size: 18) : null,
      ),
    );
  }

  void _showQuickEditDialog(BuildContext context, bool isDark, Color themeColor, Color textColor) {
    TextEditingController editCtrl = TextEditingController(text: widget.song.content);
    Color btnTextColor = _isLightColorForBg(themeColor) ? Colors.black87 : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          title: Text('Sözleri Düzenle', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: editCtrl,
              maxLines: 15, 
              style: TextStyle(color: textColor, fontSize: 13.0),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderSide: BorderSide(color: themeColor.withOpacity(0.5))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor)),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('İPTAL', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: themeColor),
              onPressed: () {
                setState(() { widget.song.content = editCtrl.text; widget.song.save(); });
                Navigator.pop(context);
              },
              child: Text('KAYDET', style: TextStyle(color: btnTextColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  void _showReaderSettings(BuildContext context, bool isDark, Color textColor, Color currentColor, Color appThemeColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OKUMA AYARLARI', style: GoogleFonts.montserrat(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text('Global Akor Rengi', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildGlobalChordColorOption(const Color(0xFFFF0033), currentColor, isDark, appThemeColor),
                    _buildGlobalChordColorOption(const Color(0xFF39FF14), currentColor, isDark, appThemeColor),
                    _buildGlobalChordColorOption(Colors.cyanAccent, currentColor, isDark, appThemeColor),
                    _buildGlobalChordColorOption(Colors.yellowAccent, currentColor, isDark, appThemeColor),
                    _buildGlobalChordColorOption(Colors.transparent, currentColor, isDark, appThemeColor, isAdaptive: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  Widget _buildGlobalChordColorOption(Color color, Color currentColor, bool isDark, Color appThemeColor, {bool isAdaptive = false}) {
    bool isSelected = currentColor == color;
    Color displayColor = isAdaptive ? (isDark ? Colors.white : Colors.black87) : color;

    return GestureDetector(
      onTap: () { 
        ref.read(globalChordColorProvider.notifier).state = color; 
        Hive.box('settings').put('chordColor', color.value); 
        Navigator.pop(context); 
      },
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
          ? Icon(Icons.check, color: isAdaptive ? appThemeColor : (_isLightColorForBg(displayColor) ? Colors.black87 : Colors.white), size: 18, shadows: isAdaptive ? [Shadow(color: isDark ? Colors.black87 : Colors.white70, blurRadius: 4)] : null) 
          : null,
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double dashWidth = 6, dashSpace = 4;
    
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(i, 0), Offset(math.min(i + dashWidth, size.width), 0), paint);
    }
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(i, size.height), Offset(math.min(i + dashWidth, size.width), size.height), paint);
    }
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(0, i), Offset(0, math.min(i + dashWidth, size.height)), paint);
    }
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      canvas.drawLine(Offset(size.width, i), Offset(size.width, math.min(i + dashWidth, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DrawingPainter extends CustomPainter {
  final List<StrokeData> strokes;
  final List<Offset> currentPoints;
  final String currentColorName;
  final double currentStrokeWidth;
  final bool isDark;
  final DrawingTool currentTool;

  DrawingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColorName,
    required this.currentStrokeWidth,
    required this.isDark,
    required this.currentTool,
  });

  Color _getColor(String name) {
    switch(name) {
      case 'red': return Colors.redAccent;
      case 'blue': return Colors.blueAccent;
      case 'green': return Colors.greenAccent;
      case 'yellow': return Colors.yellowAccent;
      case 'adaptive': return isDark ? Colors.white : Colors.black87;
      default: return Colors.redAccent;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    for (var stroke in strokes) {
      final paint = Paint()
        ..color = stroke.isEraser ? Colors.black : _getColor(stroke.colorName)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver; 
      
      if (stroke.isArrow && !stroke.isEraser) {
        _drawArrow(canvas, stroke.points, paint);
      } else {
        _drawPoints(canvas, stroke.points, paint);
      }
    }

    if (currentPoints.isNotEmpty) {
      final paint = Paint()
        ..color = currentTool == DrawingTool.eraserPixel ? Colors.black : _getColor(currentColorName)
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = currentTool == DrawingTool.eraserPixel ? BlendMode.clear : BlendMode.srcOver;
      
      if (currentTool == DrawingTool.arrow) {
        _drawArrow(canvas, currentPoints, paint);
      } else {
        _drawPoints(canvas, currentPoints, paint);
      }
    }

    canvas.restore(); 
  }

  void _drawPoints(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawPoints(PointMode.points, points, paint);
    } else if (points.length > 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawArrow(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) {
      _drawPoints(canvas, points, paint);
      return;
    }
    
    _drawPoints(canvas, points, paint);

    int backIndex = points.length > 8 ? points.length - 8 : 0;
    Offset p1 = points[backIndex];
    Offset p2 = points.last;
    
    for (int i = points.length - 2; i >= 0; i--) {
      if ((p2 - points[i]).distance > 15.0) {
        p1 = points[i];
        break;
      }
    }
    
    double dX = p2.dx - p1.dx;
    double dY = p2.dy - p1.dy;
    double angle = math.atan2(dY, dX);
    
    double arrowSize = paint.strokeWidth * 3 + 10; 

    Path arrowPath = Path();
    arrowPath.moveTo(p2.dx - arrowSize * math.cos(angle - math.pi / 6), p2.dy - arrowSize * math.sin(angle - math.pi / 6)); 
    arrowPath.lineTo(p2.dx, p2.dy); 
    arrowPath.lineTo(p2.dx - arrowSize * math.cos(angle + math.pi / 6), p2.dy - arrowSize * math.sin(angle + math.pi / 6)); 

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}