//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import flutter_vpnengine
import screen_retriever
import shared_preferences_foundation
import sqflite_darwin
import system_tray
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  VpnclientEngineFlutterPlugin.register(with: registry.registrar(forPlugin: "VpnclientEngineFlutterPlugin"))
  ScreenRetrieverPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
  SystemTrayPlugin.register(with: registry.registrar(forPlugin: "SystemTrayPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
