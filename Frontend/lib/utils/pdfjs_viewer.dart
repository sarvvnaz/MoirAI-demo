// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web; // ✅ correct import for web platform views
import 'package:flutter/material.dart';

import 'dart:js_util' as js_util;  // ✅ NEW

class PdfJsViewer extends StatefulWidget {
  final String assetPath;

  const PdfJsViewer({super.key, required this.assetPath});

  @override
  State<PdfJsViewer> createState() => _PdfJsViewerState();
}

class _PdfJsViewerState extends State<PdfJsViewer> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();

    // unique id for this canvas
    _viewId = 'pdfjs-${DateTime.now().millisecondsSinceEpoch}';

    // ✅ this is the correct API name:
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => html.CanvasElement()..id = _viewId,
    );

    // small delay so the canvas exists before JS draws into it
    Future.delayed(const Duration(milliseconds: 200), () {
      js_util.callMethod(html.window, 'renderPdf', [
        widget.assetPath,
        _viewId,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
