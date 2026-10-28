// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeTrailerWebView extends WebViewPlatform {
  final controllers = <FakeTrailerController>[];
  bool completeLoads = true;
  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final controller =
        FakeTrailerController(params, completeLoads: completeLoads);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      FakeTrailerNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      FakeTrailerWidget(params);
}

class FakeTrailerController extends PlatformWebViewController {
  FakeTrailerController(super.params, {this.completeLoads = true})
      : super.implementation();
  final bool completeLoads;
  final requests = <LoadRequestParams>[];
  final scripts = <String>[];
  String? document;
  FakeTrailerNavigation? navigation;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate delegate) async {
    navigation = delegate as FakeTrailerNavigation;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params);
    if (completeLoads) navigation?.finished?.call(params.uri.toString());
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    document = html;
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }
}

class FakeTrailerNavigation extends PlatformNavigationDelegate {
  FakeTrailerNavigation(super.params) : super.implementation();
  PageEventCallback? finished;
  WebResourceErrorCallback? resourceError;
  NavigationRequestCallback? navigate;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    resourceError = callback;
  }

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback callback) async {
    navigate = callback;
  }
}

class FakeTrailerWidget extends PlatformWebViewWidget {
  FakeTrailerWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
