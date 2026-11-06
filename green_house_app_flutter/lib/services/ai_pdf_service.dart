import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:green_house_app/services/ai_recommendation_service.dart';

/// Service untuk generate & share laporan PDF dari data rekomendasi AI.
class AiPdfService {
  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  /// Generate dan share PDF langsung via system share sheet.
  static Future<void> shareReport({
    required LiveData live,
    required DoseLogModel? latestDose,
    required List<DoseLogModel> history,
    required AIModeData mode,
  }) async {
    final pdf = await _buildDocument(
      live: live,
      latestDose: latestDose,
      history: history,
      mode: mode,
    );
    final bytes = await pdf.save();
    final filename =
        'rekomendasi_ai_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Generate PDF dan buka sistem cetak / pratinjau.
  static Future<void> printOrPreview({
    required LiveData live,
    required DoseLogModel? latestDose,
    required List<DoseLogModel> history,
    required AIModeData mode,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = await _buildDocument(
          live: live,
          latestDose: latestDose,
          history: history,
          mode: mode,
        );
        return pdf.save();
      },
    );
  }

  // ─── Document Builder ─────────────────────────────────────────────────────

  static Future<pw.Document> _buildDocument({
    required LiveData live,
    required DoseLogModel? latestDose,
    required List<DoseLogModel> history,
    required AIModeData mode,
  }) async {
    final doc = pw.Document(
      title: 'Laporan Rekomendasi AI - Greenhouse Cabai',
      author: 'AgriSense IoT',
    );

    final primaryColor = PdfColor.fromHex('#0D631B');
    final accentColor = PdfColor.fromHex('#00639A');
    final bgLight = PdfColor.fromHex('#F2F4F7');
    final textDark = PdfColor.fromHex('#191C1E');
    final textMuted = PdfColor.fromHex('#707A6C');

    // ── Page 1: Summary ──────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (ctx) => _buildHeader(
          ctx,
          primaryColor: primaryColor,
          textMuted: textMuted,
          deviceId: live.deviceId,
        ),
        footer: (ctx) => _buildFooter(ctx, textMuted: textMuted),
        build: (ctx) => [
          // Mode Badge
          _buildModeBadge(mode, primaryColor, accentColor),
          pw.SizedBox(height: 16),

          // Device Status
          _buildSection(
            title: 'Status Perangkat',
            primaryColor: primaryColor,
            child: _buildDeviceStatus(live, textDark, textMuted, bgLight),
          ),
          pw.SizedBox(height: 16),

          // Sensor Data
          _buildSection(
            title: 'Data Sensor Real-Time',
            primaryColor: primaryColor,
            child: _buildSensorTable(live.sensors, primaryColor, bgLight, textDark),
          ),
          pw.SizedBox(height: 16),

          // Latest Dose
          if (latestDose != null) ...[
            _buildSection(
              title: 'Rekomendasi Dosis Terbaru',
              primaryColor: primaryColor,
              child: _buildLatestDose(latestDose, primaryColor, accentColor, bgLight, textDark, textMuted),
            ),
            pw.SizedBox(height: 16),
          ],

          // History table
          _buildSection(
            title: 'Riwayat Dosis (${history.length} Entri Terakhir)',
            primaryColor: primaryColor,
            child: _buildHistoryTable(history, primaryColor, bgLight, textDark, textMuted),
          ),
        ],
      ),
    );

    return doc;
  }

  // ─── Header & Footer ──────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    pw.Context ctx, {
    required PdfColor primaryColor,
    required PdfColor textMuted,
    required String deviceId,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN REKOMENDASI AI',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  'Greenhouse Cabai · AgriSense IoT',
                  style: pw.TextStyle(fontSize: 9, color: textMuted),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Device: $deviceId',
                  style: pw.TextStyle(fontSize: 8, color: textMuted),
                ),
                pw.Text(
                  'Dibuat: ${_dateFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: textMuted),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(color: primaryColor, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx, {required PdfColor textMuted}) {
    return pw.Column(children: [
      pw.Divider(color: textMuted, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'AgriSense IoT Smart Greenhouse — Sistem AI Model MLP 8-10-4',
            style: pw.TextStyle(fontSize: 8, color: textMuted),
          ),
          pw.Text(
            'Halaman ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: textMuted),
          ),
        ],
      ),
    ]);
  }

  // ─── Section Wrapper ──────────────────────────────────────────────────────

  static pw.Widget _buildSection({
    required String title,
    required PdfColor primaryColor,
    required pw.Widget child,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        child,
      ],
    );
  }

  // ─── Mode Badge ───────────────────────────────────────────────────────────

  static pw.Widget _buildModeBadge(
    AIModeData mode,
    PdfColor primaryColor,
    PdfColor accentColor,
  ) {
    final badgeColor = mode.mode == 'auto'
        ? primaryColor
        : mode.mode == 'shadow'
            ? accentColor
            : PdfColor.fromHex('#707A6C');
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: badgeColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
      ),
      child: pw.Text(
        'Mode AI: ${mode.modeLabel}  |  Fase: ${mode.phase}  |  EC Setpoint: ${mode.ecSetpoint.toStringAsFixed(1)} mS/cm',
        style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  // ─── Device Status ────────────────────────────────────────────────────────

  static pw.Widget _buildDeviceStatus(
    LiveData live,
    PdfColor textDark,
    PdfColor textMuted,
    PdfColor bgLight,
  ) {
    final uptime = live.uptime;
    final h = uptime ~/ 3600;
    final m = (uptime % 3600) ~/ 60;
    final uptimeStr = '${h}j ${m}m';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _infoChip('Status', live.isOnline ? 'Online' : 'Offline', textDark, textMuted),
          _infoChip('Uptime', uptimeStr, textDark, textMuted),
          _infoChip('Terakhir Aktif', _dateFormat.format(live.lastSeen.toLocal()), textDark, textMuted),
        ],
      ),
    );
  }

  static pw.Widget _infoChip(String label, String value, PdfColor textDark, PdfColor textMuted) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: textMuted)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, color: textDark, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ─── Sensor Table ─────────────────────────────────────────────────────────

  static pw.Widget _buildSensorTable(
    Map<String, dynamic> sensors,
    PdfColor primaryColor,
    PdfColor bgLight,
    PdfColor textDark,
  ) {
    final rows = <List<dynamic>>[
      ['Parameter', 'Nilai', 'Satuan', 'Status'],
      ['Suhu Udara', _fmt(sensors['air_suhu']), '°C', _sensorStatus('air_suhu', sensors['air_suhu'])],
      ['Kelembapan Udara', _fmt(sensors['air_hum']), '%', _sensorStatus('air_hum', sensors['air_hum'])],
      ['Suhu Tanah', _fmt(sensors['tanah_suhu']), '°C', _sensorStatus('tanah_suhu', sensors['tanah_suhu'])],
      ['Kelembapan Tanah', _fmt(sensors['tanah_lembap']), '%', _sensorStatus('tanah_lembap', sensors['tanah_lembap'])],
      ['pH', _fmt(sensors['ph']), 'pH', _sensorStatus('ph', sensors['ph'])],
      ['EC', _fmt(sensors['ec']), 'µS/cm', _sensorStatus('ec', sensors['ec'])],
      ['Nitrogen (N)', _fmt(sensors['n']), 'mg/kg', '-'],
      ['Fosfor (P)', _fmt(sensors['p']), 'mg/kg', '-'],
      ['Kalium (K)', _fmt(sensors['k']), 'mg/kg', '-'],
    ];

    return pw.TableHelper.fromTextArray(
      border: null,
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      headerHeight: 22,
      cellHeight: 20,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: pw.TextStyle(color: PdfColors.grey800, fontSize: 9),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#E5E7EB'), width: 0.5)),
      ),
      headers: rows.first,
      data: rows.skip(1).toList(),
    );
  }

  static String _fmt(dynamic v) {
    if (v == null) return '-';
    final d = (v as num).toDouble();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
  }

  static String _sensorStatus(String key, dynamic value) {
    if (value == null) return '-';
    final v = (value as num).toDouble();
    switch (key) {
      case 'ph':
        return (v >= 5.5 && v <= 6.5) ? 'Normal' : 'Perlu Koreksi';
      case 'air_suhu':
        return (v >= 22 && v <= 35) ? 'Normal' : v < 22 ? 'Terlalu Dingin' : 'Panas';
      case 'air_hum':
        return (v >= 50 && v <= 80) ? 'Optimal' : 'Di Luar Rentang';
      case 'tanah_suhu':
        return v < 30 ? 'Normal' : 'Panas';
      case 'tanah_lembap':
        return v > 40 ? 'Lembap' : 'Kering';
      case 'ec':
        return v > 300 ? 'Baik' : 'Rendah';
      default:
        return '-';
    }
  }

  // ─── Latest Dose ──────────────────────────────────────────────────────────

  static pw.Widget _buildLatestDose(
    DoseLogModel dose,
    PdfColor primaryColor,
    PdfColor accentColor,
    PdfColor bgLight,
    PdfColor textDark,
    PdfColor textMuted,
  ) {
    final mlKeys = ['A', 'B', 'PH_UP', 'PH_DOWN'];
    final aiKeys = ['Pupuk A (AI)', 'Pupuk B (AI)', 'pH Up (AI)', 'pH Down (AI)'];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Metadata row
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: bgLight,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('ID Log', '#${dose.id}', textDark, textMuted),
              _infoChip('Sumber', dose.srcLabel, textDark, textMuted),
              _infoChip('Fase', 'Fase ${dose.phase}', textDark, textMuted),
              _infoChip('Waktu', _dateFormat.format(dose.timestamp.toLocal()), textDark, textMuted),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        // Dosis tabel
        pw.TableHelper.fromTextArray(
          border: null,
          cellAlignment: pw.Alignment.center,
          headerDecoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          headerHeight: 22,
          cellHeight: 22,
          headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(color: PdfColors.grey800, fontSize: 9),
          rowDecoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#E5E7EB'), width: 0.5)),
          ),
          headers: ['Nutrisi', 'Dosis Eksekusi (ml)', if (dose.hasAiPrediction) 'Prediksi AI (ml)', 'Selisih (ml)'],
          data: List.generate(mlKeys.length, (i) {
            final key = mlKeys[i];
            final executed = dose.ml[key] ?? 0.0;
            final aiVal = (dose.hasAiPrediction && i < dose.aiMl!.length) ? dose.aiMl![i] : null;
            final diff = aiVal != null ? (aiVal - executed).abs() : null;
            return [
              aiKeys[i],
              '${executed.toStringAsFixed(1)} ml',
              if (dose.hasAiPrediction) aiVal != null ? '${aiVal.toStringAsFixed(1)} ml' : '-',
              diff != null ? '${diff.toStringAsFixed(1)} ml' : '-',
            ];
          }),
        ),
      ],
    );
  }

  // ─── History Table ────────────────────────────────────────────────────────

  static pw.Widget _buildHistoryTable(
    List<DoseLogModel> history,
    PdfColor primaryColor,
    PdfColor bgLight,
    PdfColor textDark,
    PdfColor textMuted,
  ) {
    if (history.isEmpty) {
      return pw.Text('Belum ada riwayat dosis.', style: pw.TextStyle(color: textMuted, fontSize: 9));
    }

    return pw.TableHelper.fromTextArray(
      border: null,
      cellAlignment: pw.Alignment.center,
      headerDecoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      headerHeight: 22,
      cellHeight: 18,
      headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold),
      cellStyle: pw.TextStyle(color: PdfColors.grey800, fontSize: 7),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#E5E7EB'), width: 0.5)),
      ),
      headers: ['#', 'Waktu', 'Sumber', 'Fase', 'A (ml)', 'B (ml)', 'pH Up', 'pH Down', 'AI A', 'AI B'],
      data: history.map((d) {
        final aVal = d.ml['A'] ?? 0.0;
        final bVal = d.ml['B'] ?? 0.0;
        final upVal = d.ml['PH_UP'] ?? 0.0;
        final downVal = d.ml['PH_DOWN'] ?? 0.0;
        final aiA = (d.hasAiPrediction && d.aiMl!.isNotEmpty) ? d.aiMl![0] : null;
        final aiB = (d.hasAiPrediction && d.aiMl!.length > 1) ? d.aiMl![1] : null;
        return [
          '${d.id}',
          DateFormat('dd/MM HH:mm').format(d.timestamp.toLocal()),
          d.srcLabel,
          'F${d.phase}',
          aVal.toStringAsFixed(1),
          bVal.toStringAsFixed(1),
          upVal.toStringAsFixed(1),
          downVal.toStringAsFixed(1),
          aiA != null ? aiA.toStringAsFixed(1) : '-',
          aiB != null ? aiB.toStringAsFixed(1) : '-',
        ];
      }).toList(),
    );
  }
}
