import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    // Run on launch, make UI!
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Make game window using screen bounds
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Make view controller to present scenes
        let viewController = GameViewController()
        
        if let createdWindow = window {
            createdWindow.rootViewController = viewController; // Assign it to the newly made window
            createdWindow.makeKeyAndVisible(); // Make key window; the one that's visible and receives inputs
        }
        
        return true; // Has the app successfully launched or not?
    }
}
