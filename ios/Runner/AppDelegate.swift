import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var appIsActive = true
  private var screenProtectionOverlay: UIView?
  private var screenProtectionObservers: [NSObjectProtocol] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    setScreenProtection()
    return launched
  }

  private func setScreenProtection() {
    let center = NotificationCenter.default
    screenProtectionObservers = [
      center.addObserver(
        forName: UIScreen.capturedDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in self?.updateScreenProtectionOverlay() },
      center.addObserver(
        forName: UIApplication.willResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.appIsActive = false
        self?.updateScreenProtectionOverlay()
      },
      center.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.appIsActive = true
        self?.updateScreenProtectionOverlay()
      }
    ]
    updateScreenProtectionOverlay()
  }

  private func updateScreenProtectionOverlay() {
    guard let view = window?.rootViewController?.view else { return }
    let shouldCoverScreen =
      !appIsActive || UIScreen.main.isCaptured

    if shouldCoverScreen {
      if screenProtectionOverlay == nil {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = .black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.isUserInteractionEnabled = false
        screenProtectionOverlay = overlay
      }
      if screenProtectionOverlay?.superview !== view {
        view.addSubview(screenProtectionOverlay!)
      }
    } else {
      screenProtectionOverlay?.removeFromSuperview()
    }
  }

}
