import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  runApp(const LMArenaApp());
}

class LMArenaApp extends StatelessWidget {
  const LMArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LM Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;
  double loadingProgress = 0;
  bool hasError = false;

  final String targetUrl = 'https://lmarena.ai/c/new?chat-modality=chat&mode=direct';

  final String desktopUserAgent = 
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    initWebView();
  }

  void initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(desktopUserAgent)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              hasError = false;
            });
          },
          onProgress: (int progress) {
            setState(() {
              loadingProgress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            injectFixes();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              hasError = true;
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  void injectFixes() {
    const String jsCode = '''
      (function() {
        var style = document.createElement('style');
        style.id = 'mobile-fixes';
        style.innerHTML = `
          textarea, input[type="text"], input[type="search"] {
            -webkit-appearance: none !important;
            appearance: none !important;
            opacity: 1 !important;
            color: inherit !important;
            background: inherit !important;
          }
          
          [class*="message"], [class*="Message"],
          [class*="chat"], [class*="Chat"],
          [class*="response"], [class*="Response"],
          [class*="content"], [class*="Content"] {
            visibility: visible !important;
            opacity: 1 !important;
            display: block !important;
            color: inherit !important;
          }
          
          body, html, div {
            -webkit-overflow-scrolling: touch !important;
          }
          
          [class*="flex"] {
            display: flex !important;
          }
          
          p, span, div, pre, code {
            visibility: visible !important;
            opacity: 1 !important;
          }
        `;
        
        var oldStyle = document.getElementById('mobile-fixes');
        if (oldStyle) oldStyle.remove();
        
        document.head.appendChild(style);
        
        document.body.style.display = 'none';
        document.body.offsetHeight;
        document.body.style.display = '';
      })();
    ''';
    controller.runJavaScript(jsCode);
  }

  Future<void> refresh() async {
    setState(() {
      hasError = false;
    });
    await controller.reload();
  }

  Future<void> goHome() async {
    setState(() {
      hasError = false;
    });
    await controller.loadRequest(Uri.parse(targetUrl));
  }

  Future<bool> onWillPop() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'LM Arena',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: refresh,
            ),
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: '首页',
              onPressed: goHome,
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'clear':
                    await controller.clearCache();
                    await refresh();
                    break;
                  case 'reload':
                    await goHome();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Text('清除缓存'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reload',
                  child: Row(
                    children: [
                      Icon(Icons.replay),
                      SizedBox(width: 8),
                      Text('重新加载'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            
            if (isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: loadingProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 3,
                ),
              ),
            
            if (isLoading && loadingProgress < 0.3)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('加载中...'),
                    ],
                  ),
                ),
              ),
            
            if (hasError)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '加载失败',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '请检查网络连接',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
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
