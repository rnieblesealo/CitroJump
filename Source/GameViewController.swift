import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
      
        // Create new SpriteKit view
        let skView = SKView(frame: UIScreen.main.bounds)
      
        // Make it the view of this controller
        self.view = skView
        
        // Instantiate game scene
        let scene = GameScene(size: view.bounds.size)

        // Scale it to fill screen
        scene.scaleMode = .aspectFill
        
        // Present it
        skView.presentScene(scene)
        
        // Optionally show node count and frames
        skView.showsNodeCount = true;
        skView.showsFPS = true;
    }
}
