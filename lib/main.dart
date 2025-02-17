import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:async';

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
      home: WebViewScreen(url: "https://demopatient.labexpert.in//Login/Login"),
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
  bool isDownloading = false;
  bool isLoading = true;
  bool isServerDown = false;
  bool isOffline = false; // Track internet connectivity
  Timer? _serverTimeout;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection(); // Check internet on start
  }

  Future<void> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool hasInternet = connectivityResult != ConnectivityResult.none;

    if (!hasInternet) {
      setState(() {
        isOffline = true;
      });
    } else {
      setState(() {
        isOffline = false;
      });
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            isLoading = true;
            isServerDown = false;
          });

          _serverTimeout = Timer(Duration(seconds: 10), () {
            setState(() {
              isServerDown = true;
              isLoading = false;
            });
          });
        },
        onPageFinished: (String url) {
          setState(() {
            isLoading = false;
            isServerDown = false;
          });

          _serverTimeout?.cancel();
        },
        onNavigationRequest: (NavigationRequest request) async {
          String url = request.url;

          if (_isPDF(url) || await _isDownloadable(url)) {
            _downloadFile(url);
            return NavigationDecision.prevent;
          } else if (_shouldOpenInChrome(url)) {
            _openInChrome(url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  bool _isPDF(String url) {
    return url.toLowerCase().endsWith('.pdf');
  }

  Future<bool> _isDownloadable(String url) async {
    try {
      Response response = await Dio().head(url);
      String? contentType = response.headers.value('content-type');

      List<String> fileTypes = ['application/pdf', 'application/octet-stream', 'application/zip'];
      return contentType != null && fileTypes.any((type) => contentType.contains(type));
    } catch (e) {
      return false;
    }
  }

  bool _shouldOpenInChrome(String url) {
    return Uri.parse(url).host != Uri.parse(widget.url).host;
  }

  Future<void> _openInChrome(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadFile(String url) async {
    try {
      setState(() {
        isDownloading = true;
      });

      Dio dio = Dio();
      var dir = await getApplicationDocumentsDirectory();
      String fileName = url.split('/').last;
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName += '.pdf';
      }
      String savePath = '${dir.path}/$fileName';
      await dio.download(url, savePath);

      setState(() {
        isDownloading = false;
      });

      OpenFilex.open(savePath, type: "application/pdf");
    } catch (e) {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<bool> _handleBackPress() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (isOffline) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                "No Internet Connection",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkInternetConnection,
                child: Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (isServerDown) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                "Server is down. Please try again later.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isServerDown = false;
                    isLoading = true;
                  });
                  _controller.loadRequest(Uri.parse(widget.url));
                },
                child: Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

  /*  if (isDownloading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }*/

    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(8),
          child: AppBar(title: Text(""), centerTitle: true),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),

            if (isLoading||isDownloading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
