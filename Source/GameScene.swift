import SpriteKit

class GameScene: SKScene {
    let cube = SKShapeNode(rectOf: CGSize(width: 100, height: 100))
    
    // Run when moving to scene
    override func didMove(to view: SKView) {
        self.addChild(cube)
       
        cube.position = CGPoint(x: view.frame.midX, y: view.frame.midY)
    }
        
    // Run every frame
    override func update(_ currentTime: TimeInterval) {
    }
}
