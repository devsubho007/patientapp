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
      title: 'WebView & Chrome',
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
  bool isDownloading = false; // State to track download progress

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) async {
          String url = request.url;
          if (await _isDownloadable(url)) {
            _downloadFile(url); // If it's a file, download it
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

  // Function to check if the URL is a downloadable file (checks HTTP headers)
  Future<bool> _isDownloadable(String url) async {
    try {
      Response response = await Dio().head(url);
      String? contentType = response.headers.value('content-type');

      // Check if the content type is a file (e.g., PDF, ZIP, etc.)
      List<String> fileTypes = ['application/pdf', 'application/octet-stream', 'application/zip'];
      return contentType != null && fileTypes.any((type) => contentType.contains(type));
    } catch (e) {
      return false; // If we can't determine, assume it's not downloadable
    }
  }

  // Check if the URL should open in Chrome (external domain)
  bool _shouldOpenInChrome(String url) {
    return Uri.parse(url).host != Uri.parse(widget.url).host;
  }

  // Open link in Chrome (or default browser)
  Future<void> _openInChrome(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Download the file using Dio
  Future<void> _downloadFile(String url) async {
    try {
      setState(() {
        isDownloading = true; // Show loader
      });

      Dio dio = Dio();
      var dir = await getApplicationDocumentsDirectory(); // Get local storage path
      String fileName = "downloaded_file.pdf"; // Default filename (adjust as needed)
      String savePath = '${dir.path}/$fileName';

      await dio.download(url, savePath);

      setState(() {
        isDownloading = false; // Hide loader when done
      });

      OpenFilex.open(savePath); // Open the downloaded file
    } catch (e) {
      setState(() {
        isDownloading = false; // Hide loader on error
      });
    }
  }

  // Handle back button press
  Future<bool> _handleBackPress() async {
    if (await _controller.canGoBack()) {
      _controller.goBack(); // Navigate back in WebView
      return false; // Prevent app from closing
    }
    return true; // Allow app to close
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress, // Intercept back button
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(8), // Set AppBar height to 30px
          child: AppBar(
            title: Text(""),
            centerTitle: true, // Optional: Centers the title
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isDownloading)
              Container(
                color: Colors.black.withOpacity(0.5), // Semi-transparent background
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
