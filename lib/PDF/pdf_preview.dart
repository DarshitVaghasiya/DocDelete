import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class WebPdfViewerScreen extends StatefulWidget {
  final Uint8List bytes;
  final String? customerEmail;

  const WebPdfViewerScreen({
    super.key,
    required this.bytes,
    this.customerEmail,
  });

  @override
  State<WebPdfViewerScreen> createState() => _WebPdfViewerScreenState();
}

class _WebPdfViewerScreenState extends State<WebPdfViewerScreen> {
  bool isLoading = false;
  String? _viewId;
  String? _url;

  bool get _isMobile {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad');
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !_isMobile) {
      final blob = html.Blob([widget.bytes], 'application/pdf');
      _url = html.Url.createObjectUrlFromBlob(blob);
      _viewId = 'pdf-${DateTime.now().millisecondsSinceEpoch}';

      ui.platformViewRegistry.registerViewFactory(_viewId!, (int viewId) {
        return html.IFrameElement()
          ..src = _url!
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
      });
    }
  }

  @override
  void dispose() {
    if (_url != null) {
      html.Url.revokeObjectUrl(_url!);
    }
    super.dispose();
  }

  Future<void> sharePdf() async {
    setState(() {
      isLoading = true;
    });

    try {
      final base64Pdf = base64Encode(widget.bytes);
      final sendEmailUrl = ApiUrls.sendEmail;
      final response = await http.post(
        Uri.parse(sendEmailUrl),
        body: {"email": widget.customerEmail ?? "", "pdf": base64Pdf},
      );

      final data = jsonDecode(response.body);

      if (data["status"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email Sent Successfully"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Failed: ${data["message"]}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(title: "Manifest PDF"),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isMobile
                    ? SfPdfViewer.memory(widget.bytes)
                    : (_viewId != null
                          ? HtmlElementView(viewType: _viewId!)
                          : const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.darkGreen,
                              ),
                            )),
              ),
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomIconButton(
                        label: "Send to E-mail",
                        backgroundColor: AppColors.darkGreen,
                        textColor: Colors.white,
                        onTap: isLoading ? null : sharePdf,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomIconButton(
                        label: "Close",
                        borderColor: AppColors.red,
                        textColor: AppColors.red,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              ),
            ),
        ],
      ),
    );
  }
}
