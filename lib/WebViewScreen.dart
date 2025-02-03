import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WebView App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.endsWith(".pdf")) {
            _downloadPDF(request.url);
            return NavigationDecision.prevent; // Prevent WebView from loading the PDF
          }
          return NavigationDecision.navigate; // Otherwise, load normally
        },
      ))
      ..loadRequest(Uri.parse("https://portal.themeditek.com/"));
  }

  // Function to download the PDF
  Future<void> _downloadPDF(String url) async {
    // Request storage permission (important for Android)
    await _requestPermission();

    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: '/storage/emulated/0/Download',  // You can specify the path where you want to save the file
      fileName: 'downloaded_file.pdf',
      showNotification: true, // Show a download notification
      openFileFromNotification: true, // Open the file automatically after download
    );
    print('Download task ID: $taskId');
  }

  // Request permission for Android
  Future<void> _requestPermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      print("Permission granted");
    } else {
      print("Permission denied");
    }
  }

  Future<bool> _goBack(BuildContext context) async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _goBack(context),
      child: Scaffold(
        appBar: AppBar(title: Text("WebView")),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
