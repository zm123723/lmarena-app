import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
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
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  late final WebViewController controller;
  bool isLoading = true;
  double loadingProgress = 0;
  bool hasError = false;
  String errorMessage = '';
  Timer? _fixTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  final String targetUrl = 'https://lmarena.ai/c/new?chat-modality=chat&mode=direct';

  final String desktopUserAgent = 
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initWebView();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fixTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        injectFixes();
      });
    }
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
            if (mounted) {
              setState(() {
                isLoading = true;
                hasError = false;
                errorMessage = '';
              });
            }
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                loadingProgress = progress / 100;
              });
            }
            
            if (progress >= 80) {
              injectFixes();
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                isLoading = false;
                _retryCount = 0;
              });
            }
            
            injectFixes();
            Future.delayed(const Duration(milliseconds: 500), injectFixes);
            Future.delayed(const Duration(seconds: 1), injectFixes);
            Future.delayed(const Duration(seconds: 2), injectFixes);
            
            _fixTimer?.cancel();
            _fixTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
              injectFixes();
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
            
            if (mounted) {
              setState(() {
                hasError = true;
                isLoading = false;
                errorMessage = error.description ?? '加载失败';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      await controller.loadRequest(Uri.parse(targetUrl));
    } catch (e) {
      debugPrint('Load page error: $e');
      if (mounted) {
        setState(() {
          hasError = true;
          errorMessage = '页面加载失败';
        });
      }
    }
  }

  void injectFixes() {
    const String jsCode = '''
      (function() {
        try {
          var style = document.getElementById('mobile-fixes');
          if (!style) {
            style = document.createElement('style');
            style.id = 'mobile-fixes';
            document.head.appendChild(style);
          }
          
          style.innerHTML = \`
            textarea, 
            input[type="text"], 
            input[type="search"],
            input[type="email"],
            input[type="password"] {
              -webkit-appearance: none !important;
              appearance: none !important;
              opacity: 1 !important;
              color: inherit !important;
              background: inherit !important;
            }
            
            [class*="message"], 
            [class*="Message"],
            [class*="chat"], 
            [class*="Chat"],
            [class*="response"], 
            [class*="Response"],
            [class*="content"], 
            [class*="Content"] {
              visibility: visible !important;
              opacity: 1 !important;
              display: block !important;
              color: inherit !important;
            }
            
            button, 
            [role="button"],
            [type="button"],
            [type="submit"],
            a[href] {
              cursor: pointer !important;
              pointer-events: auto !important;
              -webkit-tap-highlight-color: rgba(0,0,0,0.1) !important;
              touch-action: manipulation !important;
            }
            
            body, html, div, main {
              -webkit-overflow-scrolling: touch !important;
            }
            
            [class*="flex"] {
              display: flex !important;
            }
            
            p, span, div, pre, code, h1, h2, h3, h4, h5, h6 {
              visibility: visible !important;
              opacity: 1 !important;
            }
            
            [role="dialog"],
            [class*="modal"],
            [class*="Modal"],
            [class*="dialog"],
            [class*="Dialog"] {
              visibility: visible !important;
              opacity: 1 !important;
              pointer-events: auto !important;
            }
            
            img {
              max-width: 100% !important;
              height: auto !important;
            }
          \`;
          
          var buttons = document.querySelectorAll('button, [role="button"], [type="button"], [type="submit"]');
          buttons.forEach(function(btn) {
            btn.style.pointerEvents = 'auto';
            btn.style.cursor = 'pointer';
            btn.style.touchAction = 'manipulation';
            
            if (!btn.hasAttribute('data-fixed')) {
              btn.setAttribute('data-fixed', 'true');
              
              btn.addEventListener('touchend', function(e) {
                e.stopPropagation();
                var clickEvent = new MouseEvent('click', {
                  bubbles: true,
                  cancelable: true,
                  view: window
                });
                btn.dispatchEvent(clickEvent);
              }, {passive: true});
            }
          });
          
          var inputs = document.querySelectorAll('input, textarea');
          inputs.forEach(function(input) {
            input.style.opacity = '1';
            input.style.visibility = 'visible';
            input.style.pointerEvents = 'auto';
          });
          
          var links = document.querySelectorAll('a[href]');
          links.forEach(function(link) {
            link.style.pointerEvents = 'auto';
            link.style.cursor = 'pointer';
          });
          
          document.body.style.display = 'none';
          document.body.offsetHeight;
          document.body.style.display = '';
          
          console.log('Mobile fixes applied');
          return true;
        } catch (error) {
          console.error('Fix error:', error);
          return false;
        }
      })();
    ''';
    
    controller.runJavaScript(jsCode).catchError((error) {
      debugPrint('Fix injection error: $error');
    });
  }

  Future<void> refresh() async {
    if (mounted) {
      setState(() {
        hasError = false;
        errorMessage = '';
        _retryCount = 0;
      });
    }
    await controller.reload();
  }

  Future<void> goHome() async {
    if (mounted) {
      setState(() {
        hasError = false;
        errorMessage = '';
        _retryCount = 0;
      });
    }
    await _loadPage();
  }

  Future<void> clearDataAndReload() async {
    await controller.clearCache();
    await controller.clearLocalStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('缓存已清除'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await refresh();
  }

  Future<bool> onWillPop() async {
    try {
      if (await controller.canGoBack()) {
        await controller.goBack();
        return false;
      }
    } catch (e) {
      debugPrint('Back error: $e');
    }
    return true;
  }

  void _handleRetry() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      refresh();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('多次重试失败，请检查网络'),
            action: SnackBarAction(
              label: '强制刷新',
              onPressed: () {
                _retryCount = 0;
                clearDataAndReload();
              },
            ),
          ),
        );
      }
    }
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
              onPressed: isLoading ? null : refresh,
            ),
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: '首页',
              onPressed: isLoading ? null : goHome,
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'clear':
                    await clearDataAndReload();
                    break;
                  case 'fix':
                    injectFixes();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已修复界面'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                    break;
                  case 'forward':
                    if (await controller.canGoForward()) {
                      await controller.goForward();
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'fix',
                  child: Row(
                    children: [
                      Icon(Icons.build),
                      SizedBox(width: 12),
                      Text('修复界面'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      SizedBox(width: 12),
                      Text('清除缓存'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'forward',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward),
                      SizedBox(width: 12),
                      Text('前进'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: controller),
              
              if (isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: loadingProgress > 0 ? loadingProgress : null,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              
              if (isLoading && loadingProgress < 0.3)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
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
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '加载失败',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage.isNotEmpty ? errorMessage : '请检查网络连接',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: clearDataAndReload,
                                icon: const Icon(Icons.delete),
                                label: const Text('清除缓存'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _handleRetry,
                                icon: const Icon(Icons.refresh),
                                label: const Text('重试'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
