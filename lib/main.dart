import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WebView & PDF Download',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WebViewScreen(url: "https://portal.themeditek.com/"),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  WebViewScreen({required this.url});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController _controller;
  bool isDownloading = false; // Track download status

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) async {
          String url = request.url;

          if (_isPDF(url) || await _isDownloadable(url)) {
            _downloadFile(url); // Download PDF or other files
            return NavigationDecision.prevent;
          } else if (_shouldOpenInChrome(url)) {
            _openInChrome(url); // Open external links in Chrome
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  // Check if the URL is a direct PDF link
  bool _isPDF(String url) {
    return url.toLowerCase().endsWith('.pdf');
  }

  // Check if the URL is a downloadable file by inspecting HTTP headers
  Future<bool> _isDownloadable(String url) async {
    try {
      Response response = await Dio().head(url);
      String? contentType = response.headers.value('content-type');

      List<String> fileTypes = ['application/pdf', 'application/octet-stream', 'application/zip'];
      return contentType != null && fileTypes.any((type) => contentType.contains(type));
    } catch (e) {
      return false; // Assume not downloadable if request fails
    }
  }

  // Open external links in Chrome (or default browser)
  bool _shouldOpenInChrome(String url) {
    return Uri.parse(url).host != Uri.parse(widget.url).host;
  }

  Future<void> _openInChrome(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Download and open the file
  Future<void> _downloadFile(String url) async {
    try {
      setState(() {
        isDownloading = true; // Show loader
      });

      Dio dio = Dio();
      var dir = await getApplicationDocumentsDirectory();
      //String dir = "/storage/emulated/0/Download";
      String fileName = url.split('/').last; // Extract filename from URL
     String savePath = '${dir.path}/$fileName';
      //String savePath = "$dir/$fileName";
      print("File downloaded to: $savePath");
      await dio.download(url, savePath);

      setState(() {
        isDownloading = false; // Hide loader when done
      });

      OpenFilex.open(savePath, type: "application/pdf");// Open the downloaded file
    } catch (e) {
      setState(() {
        isDownloading = false; // Hide loader on error
      });
    }
  }

  // Handle back button navigation
  Future<bool> _handleBackPress() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(8), // Small AppBar height
          child: AppBar(
            title: Text(""),
            centerTitle: true,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isDownloading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
