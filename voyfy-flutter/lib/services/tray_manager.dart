import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/vpn_provider.dart';
import 'vpn_service.dart';

/// System tray manager for desktop platforms
class TrayManager {
  static final TrayManager _instance = TrayManager._internal();
  factory TrayManager() => _instance;
  TrayManager._internal();

  SystemTray? _systemTray;
  BuildContext? _context;
  bool _isInitialized = false;
  bool _isExiting = false;

  /// Check if running on desktop platform
  bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Initialize tray for desktop platforms
  Future<void> initialize(BuildContext context) async {
    if (!isDesktop) {
      print('TRAY MANAGER: Not desktop platform, skipping tray initialization');
      return;
    }

    if (_isInitialized) return;

    _context = context;

    try {
      // Initialize system tray
      _systemTray = SystemTray();

      await _systemTray!.initSystemTray(
        title: 'Voyfy VPN',
        iconPath: _getTrayIconPath(),
        isTemplate: Platform.isMacOS,
      );

      // Build and set menu
      await _buildMenu(context);

      // Register event handler for tray clicks
      _systemTray?.registerSystemTrayEventHandler((eventName) {
        print('TRAY MANAGER: Event received: $eventName');
        if (eventName == 'leftMouseUp' || eventName == 'click') {
          // Left click - show window
          _showWindow();
        } else if (eventName == 'rightMouseUp' || eventName == 'right-click') {
          // Right click - show menu (automatic on Windows with setContextMenu)
          _systemTray?.popUpContextMenu();
        }
      });

      // Set up window listener
      windowManager.addListener(_WindowListener(this));

      // Prevent window from closing, minimize to tray instead
      await windowManager.setPreventClose(true);

      _isInitialized = true;
      print('TRAY MANAGER: Tray initialized successfully');
    } catch (e, stackTrace) {
      print('TRAY MANAGER: Error initializing tray: $e');
      print('TRAY MANAGER: Stack trace: $stackTrace');
    }
  }

  /// Get tray icon path based on platform
  String _getTrayIconPath() {
    if (Platform.isWindows) {
      return 'assets/images/logo.ico';
    } else if (Platform.isMacOS) {
      return 'assets/images/logo.png';
    } else {
      return 'assets/images/logo.png';
    }
  }

  /// Build tray menu based on VPN state with proper alignment
  Future<void> _buildMenu(BuildContext context) async {
    if (_systemTray == null) {
      print('TRAY MANAGER: Cannot build menu - systemTray is null');
      return;
    }

    print('TRAY MANAGER: Building menu...');
    final vpnProvider = context.read<VpnProvider>();
    final isConnected = vpnProvider.status == VpnStatus.connected;
    final isConnecting = vpnProvider.status == VpnStatus.connecting;
    final selectedServer = vpnProvider.selectedServer;

    // Get current locale from context
    final locale = context.locale.languageCode;
    final isRussian = locale == 'ru';

    // Status indicator (2 chars wide for alignment)
    String statusIcon;
    String statusText;
    if (isConnected) {
      statusIcon = '🟢';
      statusText = isRussian 
          ? 'Подключено: ${selectedServer?.country ?? 'Неизвестно'}'
          : 'Connected: ${selectedServer?.country ?? 'Unknown'}';
    } else if (isConnecting) {
      statusIcon = '🟡';
      statusText = isRussian ? 'Подключение...' : 'Connecting...';
    } else {
      statusIcon = '🔴';
      statusText = isRussian ? 'Отключено' : 'Disconnected';
    }

    // Build aligned status line
    final statusLine = '$statusIcon  $statusText';

    // Create menu items with consistent alignment (icon + 2 spaces + text)
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: statusLine, enabled: false),
      MenuSeparator(),
      if (isConnected)
        MenuItemLabel(
          label: isRussian ? '⏹  Отключить' : '⏹  Disconnect',
          onClicked: (menuItem) => _handleConnectDisconnect(context),
        )
      else if (!isConnecting)
        MenuItemLabel(
          label: isRussian ? '▶  Подключить' : '▶  Connect',
          onClicked: (menuItem) => _handleConnectDisconnect(context),
        )
      else
        MenuItemLabel(label: isRussian ? '⏳  Подключение...' : '⏳  Connecting...', enabled: false),
      MenuSeparator(),
      MenuItemLabel(
        label: isRussian ? '📱  Открыть Voyfy' : '📱  Open Voyfy',
        onClicked: (menuItem) => _showWindow(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: isRussian ? '❌  Выход' : '❌  Exit Voyfy',
        onClicked: (menuItem) => _exitApp(context),
      ),
    ]);

    await _systemTray?.setContextMenu(menu);
  }

  /// Update tray menu when state changes
  Future<void> updateMenu() async {
    if (!_isInitialized || _context == null || _systemTray == null) return;
    await _buildMenu(_context!);
  }

  /// Rebuild tray menu with fresh context (for theme/language changes)
  Future<void> rebuildWithContext(BuildContext context) async {
    if (!_isInitialized || _systemTray == null) return;
    _context = context;
    print('TRAY MANAGER: Rebuilding menu with new context');
    await _buildMenu(context);
  }

  /// Handle tray icon events
  void _handleTrayEvent(String eventName, BuildContext context) {
    print('TRAY MANAGER: Event received: $eventName');
    
    // Platform-specific event handling
    if (Platform.isWindows) {
      // Windows: left-click shows window, right-click shows menu
      if (eventName == 'leftMouseUp' || eventName == 'click') {
        _showWindow();
      } else if (eventName == 'rightMouseUp' || eventName == 'right-click') {
        _systemTray?.popUpContextMenu();
      }
    } else if (Platform.isMacOS) {
      // macOS: click shows menu
      if (eventName == 'click' || eventName == 'leftMouseUp') {
        _systemTray?.popUpContextMenu();
      }
    } else {
      // Linux and others
      if (eventName == 'click' || eventName == 'leftMouseUp') {
        _showWindow();
      } else if (eventName == 'rightMouseUp' || eventName == 'right-click') {
        _systemTray?.popUpContextMenu();
      }
    }
  }

  /// Show and focus window
  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    print('TRAY MANAGER: Window shown and focused');
  }

  /// Minimize to tray (hide window)
  Future<void> _minimizeToTray() async {
    await windowManager.hide();
    print('TRAY MANAGER: Window minimized to tray');
  }

  /// Handle connect/disconnect from tray
  void _handleConnectDisconnect(BuildContext context) {
    final vpnProvider = context.read<VpnProvider>();
    vpnProvider.toggleConnection();
    // Update menu after action
    Future.delayed(Duration(milliseconds: 500), () => updateMenu());
  }

  /// Full exit - stop VPN and close app
  Future<void> _exitApp(BuildContext context) async {
    if (_isExiting) return;
    _isExiting = true;

    print('TRAY MANAGER: Full exit requested');

    try {
      final vpnProvider = context.read<VpnProvider>();
      
      // Disconnect VPN if connected
      if (vpnProvider.isConnected || vpnProvider.isConnecting) {
        print('TRAY MANAGER: Disconnecting VPN before exit');
        await vpnProvider.disconnect();
        await Future.delayed(Duration(seconds: 1));
      }

      // Allow window to close
      await windowManager.setPreventClose(false);
      
      // Close tray
      await _systemTray?.destroy();
      
      // Exit app
      exit(0);
    } catch (e) {
      print('TRAY MANAGER: Error during exit: $e');
      exit(1);
    }
  }

  /// Dispose tray resources
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      await _systemTray?.destroy();
      _isInitialized = false;
      print('TRAY MANAGER: Tray disposed');
    } catch (e) {
      print('TRAY MANAGER: Error disposing tray: $e');
    }
  }
}

/// Window event listener
class _WindowListener extends WindowListener {
  final TrayManager _trayManager;
  
  _WindowListener(this._trayManager);

  @override
  void onWindowClose() async {
    // Minimize to tray instead of closing
    print('WINDOW LISTENER: Window close requested - minimizing to tray');
    await _trayManager._minimizeToTray();
  }

  @override
  void onWindowFocus() {
    // Window focused
  }

  @override
  void onWindowBlur() {
    // Window lost focus
  }
}
