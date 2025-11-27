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
  Timer? _fixTimer;
  int _currentUA = 0;

  // 多种 User-Agent 可切换
  final List<Map<String, String>> userAgents = [
    {
      'name': 'VIVO 浏览器',
      'ua': 'Mozilla/5.0 (Linux; Android 13; V2171A; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/87.0.4280.141 Mobile Safari/537.36 VivoBrowser/15.5.0.0'
    },
    {
      'name': 'VIVO 桌面版',
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.141 Safari/537.36 VivoBrowser/15.5.0.0'
    },
    {
      'name': 'Safari Mac',
      'ua': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15'
    },
    {
      'name': 'Firefox',
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0'
    },
    {
      'name': 'Edge',
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Edg/122.0.0.0'
    },
  ];

  final String targetUrl = 'https://lmarena.ai/';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void dispose() {
    _fixTimer?.cancel();
    super.dispose();
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
            _injectFix();
            
            _fixTimer?.cancel();
            _fixTimer = Timer.periodic(const Duration(seconds: 2), (_) {
              _injectFix();
            });
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
    await controller.reload();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已切换到: ${userAgents[index]['name']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _injectFix() {
    controller.runJavaScript('''
      (function() {
        var css = document.getElementById('vivo-fix');
        if (!css) {
          css = document.createElement('style');
          css.id = 'vivo-fix';
          document.head.appendChild(css);
        }
        
        css.textContent = \`
          * {
            visibility: visible !important;
            opacity: 1 !important;
          }
          
          [class*="message"],
          [class*="Message"],
          [class*="chat"],
          [class*="Chat"],
          [class*="conversation"],
          [class*="response"],
          [class*="Response"],
          [class*="answer"],
          [class*="output"],
          [class*="result"],
          [class*="content"],
          [class*="Content"],
          [class*="bubble"],
          [class*="text"],
          [class*="markdown"],
          [class*="prose"] {
            visibility: visible !important;
            opacity: 1 !important;
            display: block !important;
            color: inherit !important;
            overflow: visible !important;
            height: auto !important;
            max-height: none !important;
            transform: none !important;
            -webkit-transform: none !important;
          }
          
          textarea,
          input[type="text"],
          [contenteditable="true"] {
            visibility: visible !important;
            opacity: 1 !important;
            color: #000 !important;
            -webkit-text-fill-color: #000 !important;
          }
          
          pre, code {
            visibility: visible !important;
            opacity: 1 !important;
            display: block !important;
            white-space: pre-wrap !important;
          }
          
          [class*="scroll"],
          [class*="container"],
          main, article, section {
            overflow: auto !important;
            -webkit-overflow-scrolling: touch !important;
          }
          
          p, span, div, h1, h2, h3, h4, h5, h6, li {
            color: inherit !important;
            visibility: visible !important;
            opacity: 1 !important;
          }
          
          [class*="stream"],
          [class*="typing"],
          [class*="loading"] {
            visibility: visible !important;
            opacity: 1 !important;
          }
          
          button, [role="button"] {
            pointer-events: auto !important;
          }
        \`;
        
        document.body.style.display = 'none';
        void document.body.offsetHeight;
        document.body.style.display = '';
        
        window.dispatchEvent(new Event('resize'));
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LM Arena (${userAgents[_currentUA]['name']})'),
        titleTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        centerTitle: true,
        actions: [
          // 刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => controller.reload(),
          ),
          // 修复显示
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: '修复显示',
            onPressed: _injectFix,
          ),
          // 菜单
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value.startsWith('ua_')) {
                int index = int.parse(value.substring(3));
                _switchUserAgent(index);
              } else {
                switch (value) {
                  case 'home':
                    controller.loadRequest(Uri.parse(targetUrl));
                    break;
                  case 'direct':
                    controller.loadRequest(Uri.parse('https://lmarena.ai/c/new?chat-modality=chat&mode=direct'));
                    break;
                  case 'battle':
                    controller.loadRequest(Uri.parse('https://lmarena.ai/c/new?chat-modality=chat&mode=battle'));
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
              const PopupMenuItem(value: 'home', child: Text('🏠 首页')),
              const PopupMenuItem(value: 'direct', child: Text('💬 直接对话')),
              const PopupMenuItem(value: 'battle', child: Text('⚔️ 模型对战')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('切换浏览器模式:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...userAgents.asMap().entries.map((entry) => 
                PopupMenuItem(
                  value: 'ua_${entry.key}',
                  child: Row(
                    children: [
                      Icon(
                        _currentUA == entry.key ? Icons.check_circle : Icons.circle_outlined,
                        size: 18,
                        color: _currentUA == entry.key ? Colors.green : Colors.grey,
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
        ],
      ),
      // 底部提示栏
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.blue.shade50,
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '如果看不到消息，请点击菜单切换浏览器模式',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () => _switchUserAgent(0),
              child: const Text('试试VIVO', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
