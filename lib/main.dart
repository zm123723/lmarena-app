import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
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
  int _currentUA = 0;

  final List<Map<String, String>> userAgents = [
    {
      'name': 'VIVO',
      'ua': 'Mozilla/5.0 (Linux; Android 13; V2171A; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/87.0.4280.141 Mobile Safari/537.36 VivoBrowser/15.5.0.0'
    },
    {
      'name': 'Chrome 桌面版',
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    },
    {
      'name': 'Safari',
      'ua': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15'
    },
    {
      'name': 'Firefox',
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0'
    },
  ];

  final String targetUrl = 'https://lmarena.ai/';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(userAgents[_currentUA]['ua']!)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => isLoading = false);
            // 不自动注入任何修复
          },
          onWebResourceError: (error) {
            debugPrint('Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  void _switchUserAgent(int index) async {
    setState(() {
      _currentUA = index;
      isLoading = true;
    });
    
    await controller.setUserAgent(userAgents[index]['ua']!);
    await controller.clearCache();
    await controller.loadRequest(Uri.parse(targetUrl));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已切换到: ${userAgents[index]['name']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 轻量级修复 - 只修复关键问题
  void _lightFix() {
    controller.runJavaScript('''
      (function() {
        // 隐藏可能遮挡的元素
        var hideSelectors = [
          '[class*="recaptcha"]',
          '[class*="grecaptcha"]',
          '[class*="privacy"]',
          '[class*="cookie"]',
          '[class*="banner"]',
          '[class*="popup"]',
          '[class*="overlay"]',
          'iframe[src*="recaptcha"]',
          'iframe[src*="google"]'
        ];
        
        hideSelectors.forEach(function(selector) {
          try {
            document.querySelectorAll(selector).forEach(function(el) {
              if (el.offsetHeight < 100 || el.style.position === 'fixed') {
                el.style.display = 'none';
              }
            });
          } catch(e) {}
        });
        
        console.log('Light fix applied');
      })();
    ''');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已清理干扰元素'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 强制修复 - 尝试修复显示问题
  void _forceFix() {
    controller.runJavaScript('''
      (function() {
        // 1. 移除所有 fixed 定位的小元素（可能是遮挡物）
        document.querySelectorAll('*').forEach(function(el) {
          var style = window.getComputedStyle(el);
          if (style.position === 'fixed' && el.offsetHeight < 150 && el.offsetWidth < 300) {
            el.style.display = 'none';
          }
        });
        
        // 2. 重新触发渲染
        window.dispatchEvent(new Event('resize'));
        
        console.log('Force fix applied');
      })();
    ''');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已尝试修复显示'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userAgents[_currentUA]['name']!),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => controller.loadRequest(Uri.parse(targetUrl)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => controller.reload(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value.startsWith('ua_')) {
                int index = int.parse(value.substring(3));
                _switchUserAgent(index);
              } else {
                switch (value) {
                  case 'direct':
                    controller.loadRequest(Uri.parse('https://lmarena.ai/c/new?chat-modality=chat&mode=direct'));
                    break;
                  case 'battle':
                    controller.loadRequest(Uri.parse('https://lmarena.ai/c/new?chat-modality=chat&mode=battle'));
                    break;
                  case 'light_fix':
                    _lightFix();
                    break;
                  case 'force_fix':
                    _forceFix();
                    break;
                  case 'clear':
                    await controller.clearCache();
                    await controller.clearLocalStorage();
                    controller.reload();
                    break;
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'direct', child: Text('💬 直接对话')),
              const PopupMenuItem(value: 'battle', child: Text('⚔️ 模型对战')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'light_fix', child: Text('🧹 清理干扰元素')),
              const PopupMenuItem(value: 'force_fix', child: Text('🔧 强制修复显示')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('切换模式:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              ...userAgents.asMap().entries.map((entry) => 
                PopupMenuItem(
                  value: 'ua_${entry.key}',
                  child: Row(
                    children: [
                      Icon(
                        _currentUA == entry.key ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18,
                        color: _currentUA == entry.key ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(entry.value['name']!),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear', child: Text('🗑️ 清除缓存')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
