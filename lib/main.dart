import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置状态栏透明
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 设置屏幕方向（支持横竖屏）
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

  // 使用 Windows Chrome 的 User-Agent，兼容性最好
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

  // 监听应用生命周期
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 应用恢复时重新注入修复
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
            
            // 页面加载到 80% 时开始注入修复
            if (progress >= 80) {
              injectFixes();
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                isLoading = false;
                _retryCount = 0; // 重置重试计数
              });
            }
            
            // 页面加载完成后立即修复
            injectFixes();
            
            // 延迟再次修复，确保动态内容也被修复
            Future.delayed(const Duration(milliseconds: 500), injectFixes);
            Future.delayed(const Duration(seconds: 1), injectFixes);
            Future.delayed(const Duration(seconds: 2), injectFixes);
            
            // 启动定时器，每 3 秒修复一次（处理动态加载的内容）
            _fixTimer?.cancel();
            _fixTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
              injectFixes();
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
            
            // 只在主资源错误时显示错误页面
            if (error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout ||
                error.errorType == WebResourceErrorType.connect) {
              if (mounted) {
                setState(() {
                  hasError = true;
                  isLoading = false;
                  errorMessage = _getErrorMessage(error.errorType);
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // 允许所有导航
            return NavigationDecision.navigate;
          },
        ),
      );

    // 加载页面
    _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      await controller.loadRequest(
        Uri.parse(targetUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'max-age=0',
        },
      );
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

  String _getErrorMessage(WebResourceErrorType errorType) {
    switch (errorType) {
      case WebResourceErrorType.hostLookup:
        return '无法连接到服务器\n请检查网络连接';
      case WebResourceErrorType.timeout:
        return '连接超时\n请稍后重试';
      case WebResourceErrorType.connect:
        return '网络连接失败';
      default:
        return '加载失败\n请检查网络';
    }
  }

  void injectFixes() {
    const String jsCode = '''
      (function() {
        try {
          // 1. 修复样式
          var style = document.getElementById('mobile-fixes');
          if (!style) {
            style = document.createElement('style');
            style.id = 'mobile-fixes';
            document.head.appendChild(style);
          }
          
          style.innerHTML = \`
            /* 修复输入框 */
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
              border-radius: 4px !important;
            }
            
            /* 修复消息显示 */
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
            
            /* 修复按钮 */
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
            
            /* 修复滚动 */
            body, html, div, main {
              -webkit-overflow-scrolling: touch !important;
              overflow: auto !important;
            }
            
            /* 修复 flex 布局 */
            [class*="flex"] {
              display: flex !important;
            }
            
            /* 确保文字可见 */
            p, span, div, pre, code, h1, h2, h3, h4, h5, h6 {
              visibility: visible !important;
              opacity: 1 !important;
            }
            
            /* 修复模态框/弹窗 */
            [role="dialog"],
            [class*="modal"],
            [class*="Modal"],
            [class*="dialog"],
            [class*="Dialog"] {
              visibility: visible !important;
              opacity: 1 !important;
              pointer-events: auto !important;
            }
            
            /* 防止内容溢出 */
            * {
              max-width: 100% !important;
              box-sizing: border-box !important;
            }
            
            img {
              max-width: 100% !important;
              height: auto !important;
            }
          \`;
          
          // 2. 修复所有按钮的点击事件
          var buttons = document.querySelectorAll('button, [role="button"], [type="button"], [type="submit"]');
          buttons.forEach(function(btn) {
            btn.style.pointerEvents = 'auto';
            btn.style.cursor = 'pointer';
            btn.style.touchAction = 'manipulation';
            
            // 确保有点击事件监听器
            if (!btn.hasAttribute('data-fixed')) {
              btn.setAttribute('data-fixed', 'true');
              
              // 添加触摸事件支持
              btn.addEventListener('touchstart', function(e) {
                e.stopPropagation();
              }, {passive: true});
              
              btn.addEventListener('touchend', function(e) {
                e.stopPropagation();
                // 触发点击
                var clickEvent = new MouseEvent('click', {
                  bubbles: true,
                  cancelable: true,
                  view: window
                });
                btn.dispatchEvent(clickEvent);
              }, {passive: true});
            }
          });
          
          // 3. 修复输入框
          var inputs = document.querySelectorAll('input, textarea');
          inputs.forEach(function(input) {
            input.style.opacity = '1';
            input.style.visibility = 'visible';
            input.style.pointerEvents = 'auto';
          });
          
          // 4. 修复链接
          var links = document.querySelectorAll('a[href]');
          links.forEach(function(link) {
            link.style.pointerEvents = 'auto';
            link.style.cursor = 'pointer';
          });
          
          // 5. 强制重绘（解决渲染问题）
          document.body.style.display = 'none';
          document.body.offsetHeight; // 触发重排
          document.body.style.display = '';
          
          // 6. 处理 Shadow DOM（某些组件可能使用）
          var shadowHosts = document.querySelectorAll('*');
          shadowHosts.forEach(function(host) {
            if (host.shadowRoot) {
              var shadowButtons = host.shadowRoot.querySelectorAll('button, [role="button"]');
              shadowButtons.forEach(function(btn) {
                btn.style.pointerEvents = 'auto';
                btn.style.cursor = 'pointer';
              });
            }
          });
          
          console.log('✅ Mobile fixes applied successfully');
          return true;
        } catch (error) {
          console.error('❌ Fix injection error:', error);
          return false;
        }
      })();
    ''';
    
    controller.runJavaScript(jsCode).then((result) {
      debugPrint('Fix injection completed');
    }).catchError((error) {
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
      debugPrint('Back navigation error: $e');
    }
    return true;
  }

  void _handleRetry() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      refresh();
    } else {
      // 超过最大重试次数，显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('多次重试失败，请检查网络连接'),
            action: SnackBarAction(
              label: '强制刷新',
              onPressed: () {
                _retryCount = 0;
                clearDataAndReload();
              },
            ),
            duration: const Duration(seconds: 5),
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
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新页面',
              onPressed: isLoading ? null : refresh,
            ),
            IconButton(
              icon: const Icon(Icons.home_rounded),
              tooltip: '返回首页',
              onPressed: isLoading ? null : goHome,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                switch (value) {
                  case 'clear':
                    await clearDataAndReload();
                    break;
                  case 'reload':
                    await goHome();
                    break;
                  case 'fix':
                    injectFixes();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已尝试修复界面'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                    break;
                  case 'forward':
                    try {
                      if (await controller.canGoForward()) {
                        await controller.goForward();
                      }
                    } catch (e) {
                      debugPrint('Forward error: $e');
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'fix',
                  child: Row(
                    children: [
                      Icon(Icons.build_rounded),
                      SizedBox(width: 12),
                      Text('修复界面'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services_rounded),
                      SizedBox(width: 12),
                      Text('清除缓存并刷新'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reload',
                  child: Row(
                    children: [
                      Icon(Icons.replay_rounded),
                      SizedBox(width: 12),
                      Text('重新加载'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'forward',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded),
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
              // WebView
              WebViewWidget(controller: controller),
              
              // 顶部进度条
              if (isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: loadingProgress > 0 ? loadingProgress : null,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 3,
                  ),
                ),
              
              // 初始加载遮罩
              if (isLoading && loadingProgress < 0.3)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '正在加载 LM Arena...',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (_retryCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '重试次数: $_retryCount/$_maxRetries',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              
              // 错误页面
              if (hasError)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 80,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '加载失败',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            errorMessage.isNotEmpty ? errorMessage : '无法连接到服务器',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_retryCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '已重试 $_retryCount 次',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: clearDataAndReload,
                                icon: const Icon(Icons.cleaning_services_rounded),
                                label: const Text('清除缓存'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _handleRetry,
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(_retryCount >= _maxRetries ? '强制重试' : '重试'),
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
