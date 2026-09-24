import UIKit
import Flutter
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: {_, _ in })
    } else {
      let settings: UIUserNotificationSettings =
      UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    // Setup method channel for native functionality
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let nativeChannel = FlutterMethodChannel(name: "com.alive.alivengandroidapp/native",
                                           binaryMessenger: controller.binaryMessenger)
    
    nativeChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "openUrl":
        if let args = call.arguments as? Dictionary<String, Any>,
           let urlString = args["url"] as? String,
           let url = URL(string: urlString) {
          if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            result(true)
          } else {
            result(FlutterError(code: "INVALID_URL", message: "Cannot open URL", details: nil))
          }
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "URL is required", details: nil))
        }
        
      case "shareText":
        if let args = call.arguments as? Dictionary<String, Any>,
           let text = args["text"] as? String {
          let subject = args["subject"] as? String
          self.shareText(text: text, subject: subject, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Text is required", details: nil))
        }
        
      case "makePhoneCall":
        if let args = call.arguments as? Dictionary<String, Any>,
           let phoneNumber = args["phoneNumber"] as? String {
          self.makePhoneCall(phoneNumber: phoneNumber, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Phone number is required", details: nil))
        }
        
      case "sendEmail":
        if let args = call.arguments as? Dictionary<String, Any>,
           let email = args["email"] as? String {
          let subject = args["subject"] as? String
          let body = args["body"] as? String
          self.sendEmail(email: email, subject: subject, body: body, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Email is required", details: nil))
        }
        
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func shareText(text: String, subject: String?, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
      
      if let subject = subject {
        activityViewController.setValue(subject, forKey: "subject")
      }
      
      if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
          popover.sourceView = rootViewController.view
          popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                    y: rootViewController.view.bounds.midY,
                                    width: 0, height: 0)
          popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true) {
          result(true)
        }
      } else {
        result(FlutterError(code: "NO_CONTROLLER", message: "No view controller available", details: nil))
      }
    }
  }
  
  private func makePhoneCall(phoneNumber: String, result: @escaping FlutterResult) {
    if let url = URL(string: "tel://\(phoneNumber)") {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        result(true)
      } else {
        result(FlutterError(code: "CANNOT_CALL", message: "Cannot make phone calls on this device", details: nil))
      }
    } else {
      result(FlutterError(code: "INVALID_NUMBER", message: "Invalid phone number", details: nil))
    }
  }
  
  private func sendEmail(email: String, subject: String?, body: String?, result: @escaping FlutterResult) {
    var urlString = "mailto:\(email)"
    var queryItems: [String] = []
    
    if let subject = subject {
      queryItems.append("subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
    
    if let body = body {
      queryItems.append("body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
    
    if !queryItems.isEmpty {
      urlString += "?" + queryItems.joined(separator: "&")
    }
    
    if let url = URL(string: urlString) {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        result(true)
      } else {
        result(FlutterError(code: "NO_EMAIL_APP", message: "No email app available", details: nil))
      }
    } else {
      result(FlutterError(code: "INVALID_EMAIL", message: "Invalid email address", details: nil))
    }
  }
}