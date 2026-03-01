import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/song_model.dart';

class PdfService {
  static const List<String> _notesSharps = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
  static const Map<String,int> _noteIndex = {
    'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,
    'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11
  };

  static String _transposeChord(String chord, int step) {
    if (step == 0) return chord;
    final m = RegExp(r'^([A-G][#b]?)(.*)').firstMatch(chord);
    if (m == null) return chord;
    final root = m.group(1)!, suf = m.group(2)!;
    int idx = _noteIndex[root] ?? 0;
    int ni  = (idx + step) % 12;
    if (ni < 0) ni += 12;
    return _notesSharps[ni] + suf;
  }

  static PdfColor _getPdfColor(String? colorName) {
    if (colorName == 'red') return PdfColors.red;
    if (colorName == 'blue') return PdfColors.blue;
    if (colorName == 'green') return PdfColors.green;
    if (colorName == 'yellow') return PdfColors.orange; // Sarı renk beyaz kağıtta görünmez, turuncuya çekilir
    return PdfColors.black;
  }

  static Future<String> exportToPdf({
    required String exportTitle,
    required List<SongModel> songs,
    required bool includeDrawings,
  }) async {
    try {
      final pdf = pw.Document();

      pw.Font fontRegular;
      pw.Font fontBold;

      try {
        fontRegular = await PdfGoogleFonts.montserratRegular();
        fontBold = await PdfGoogleFonts.montserratBold();
      } catch (e) {
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }

      final drawBox = await Hive.openBox<String>('drawings_box');

      // UYGULAMA (16 punto) İLE PDF (14 punto) ARASINDAKİ MATEMATİKSEL KÜÇÜLTME ORANI
      const double scale = 14.0 / 16.0; // 0.875

      for (var song in songs) {
        final spans = <pw.TextSpan>[];
        final rx = RegExp(
          r'(?<=\s|\[|^)' +
          r'([A-G](?:#|b)?(?:m|maj|min|dim|aug|sus|add|ø|o)?(?:maj7|m7|7|6|9|11|13|2|4)?)' +
          r'(?=\s|\]|$)'
        );

        String cleanText = song.content.replaceAll('\r', '');
        for (var line in cleanText.split('\n')) {
          int last = 0;
          for (final m in rx.allMatches(line)) {
            if (m.start > last) {
              spans.add(pw.TextSpan(text: line.substring(last, m.start)));
            }
            spans.add(pw.TextSpan(
              text: _transposeChord(m.group(1)!, song.transposeStep),
              style: pw.TextStyle(font: fontBold, color: PdfColors.red),
            ));
            last = m.end;
          }
          if (last < line.length) {
            spans.add(pw.TextSpan(text: line.substring(last)));
          }
          spans.add(const pw.TextSpan(text: '\n'));
        }

        pw.Widget? strokesWidget;
        List<pw.Widget> textAnnotations = [];

        if (includeDrawings) {
          String? drawStr = drawBox.get(song.id);
          if (drawStr != null) {
            List decodedStrokes = jsonDecode(drawStr);
            strokesWidget = pw.Positioned.fill(
              child: pw.CustomPaint(
                painter: (PdfGraphics canvas, PdfPoint size) {
                  for (var s in decodedStrokes) {
                    if (s['isEraser'] == true) continue;
                    List pts = s['points'];
                    if (pts.isEmpty) continue;

                    double strokeWidth = (s['width'] as num).toDouble();
                    bool isArrow = s['isArrow'] ?? false;
                    
                    canvas.setStrokeColor(_getPdfColor(s['color']));
                    canvas.setLineWidth(strokeWidth * scale); // Çizgi kalınlığı 14 puntoya uyarlandı
                    canvas.setLineCap(PdfLineCap.round);
                    canvas.setLineJoin(PdfLineJoin.round);

                    // KOORDİNAT SİSTEMİ ÇEVİRİSİ (Uygulama Y ekseni tersine çevriliyor)
                    double getX(dynamic pt) => (pt['x'] as num).toDouble() * scale;
                    double getY(dynamic pt) => size.y - ((pt['y'] as num).toDouble() * scale); 

                    canvas.moveTo(getX(pts[0]), getY(pts[0]));
                    for (int i = 1; i < pts.length; i++) {
                      canvas.lineTo(getX(pts[i]), getY(pts[i]));
                    }
                    canvas.strokePath();

                    // KUSURSUZ OK ÇİZİMİ
                    if (isArrow && pts.length >= 2) {
                      int backIndex = pts.length > 8 ? pts.length - 8 : 0;
                      var p1 = math.Point<double>(getX(pts[backIndex]), getY(pts[backIndex]));
                      var p2 = math.Point<double>(getX(pts.last), getY(pts.last));
                      
                      for (int i = pts.length - 2; i >= 0; i--) {
                        var pi = math.Point<double>(getX(pts[i]), getY(pts[i]));
                        double dist = math.sqrt(math.pow(p2.x - pi.x, 2) + math.pow(p2.y - pi.y, 2));
                        if (dist > 15.0 * scale) { // Mesafe toleransı da orantılandı
                          p1 = pi;
                          break;
                        }
                      }
                      
                      double dX = p2.x - p1.x;
                      double dY = p2.y - p1.y;
                      double angle = math.atan2(dY, dX);
                      double arrowSize = (strokeWidth * 3 + 10) * scale; 

                      canvas.moveTo(p2.x - arrowSize * math.cos(angle - math.pi / 6), p2.y - arrowSize * math.sin(angle - math.pi / 6));
                      canvas.lineTo(p2.x, p2.y);
                      canvas.lineTo(p2.x - arrowSize * math.cos(angle + math.pi / 6), p2.y - arrowSize * math.sin(angle + math.pi / 6));
                      canvas.strokePath();
                    }
                  }
                }
              )
            );
          }

          // METİN NOTLARINI (ÖRN: "deneme") YERLEŞTİRME
          String? textsStr = drawBox.get('${song.id}_texts');
          if (textsStr != null) {
            List decodedTexts = jsonDecode(textsStr);
            for (var node in decodedTexts) {
              textAnnotations.add(
                pw.Positioned(
                  left: (node['x'] as num).toDouble() * scale,
                  top: (node['y'] as num).toDouble() * scale,
                  child: pw.Transform.rotateBox(
                    angle: (node['rotation'] as num?)?.toDouble() ?? 0.0,
                    child: pw.Text(
                      node['text'],
                      style: pw.TextStyle(
                        color: _getPdfColor(node['color']), 
                        fontSize: 24 * ((node['scale'] as num?)?.toDouble() ?? 1.0) * scale, 
                        font: fontBold
                      )
                    )
                  )
                )
              );
            }
          }
        }

        // --- TEK SAYFA (MAKBUZ TİPİ) OLUŞTURMA MOTORU ---
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4, 
            margin: const pw.EdgeInsets.all(30),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // SABİT BAŞLIK BÖLÜMÜ
                  pw.Text(song.title.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.black)),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: PdfColors.grey300, thickness: 2),
                  pw.SizedBox(height: 15),
                  
                  // DİNAMİK İÇERİK BÖLÜMÜ (SIĞMAZSA KÜÇÜLEN YAPI)
                  pw.Expanded(
                    child: pw.FittedBox(
                      alignment: pw.Alignment.topLeft,
                      // SİHİRLİ KOMUT: Eğer 14 puntoyla A4 yüksekliğini aşarsa, sayfa altına değene kadar küçültür.
                      // Eğer sığıyorsa, orijinal boyutunda (14pt) bırakır.
                      fit: pw.BoxFit.scaleDown, 
                      child: pw.Container(
                        constraints: const pw.BoxConstraints(minWidth: 515), // A4'ün genişliğine kilitlendi
                        child: pw.Stack(
                          children: [
                            pw.RichText(
                              text: pw.TextSpan(
                                style: pw.TextStyle(
                                  font: fontRegular, 
                                  fontSize: 14, // İstenen ana punto
                                  lineSpacing: 8.4, // Uygulamadaki 1.6 yükseklik oranının PDF karşılığı
                                  color: PdfColors.black
                                ),
                                children: spans,
                              )
                            ),
                            if (strokesWidget != null) strokesWidget,
                            ...textAnnotations,
                          ]
                        )
                      )
                    )
                  )
                ]
              );
            }
          )
        );
      }

      final directory = await getTemporaryDirectory();
      String safeTitle = exportTitle.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
      final file = File('${directory.path}/$safeTitle.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: '$exportTitle - PDF Repertuvarı');
      
      return "OK";
    } catch (e) {
      return "Hata oluştu: ${e.toString()}";
    }
  }
}