import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    let cube = SKShapeNode(rectOf: CGSize(width: 100, height: 100))
   
    let motionManager = CMMotionManager()
    let xTiltSensitivity = 10.0
    let yTiltSensitivity = 3.0
    let gravity = -9.81
   
    func configureMotion(){
        // Start accelerometer
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.02 // 50 updates per secon
            motionManager.startAccelerometerUpdates()
        }
    }
   
    func configureCube(){
        // Add physics body to cube
        let physicsBody = SKPhysicsBody(rectangleOf: cube.bounds.size)
        
        physicsBody.isDynamic = true // Apply updates
        physicsBody.collisionBitMask = 0 // Can collide w/anything
        
        cube.physicsBody = physicsBody
    }
  
    func configurePhysics(){
        self.physicsWorld.contactDelegate = self // Make contact tests take place in this scene
        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0) // Remove global gravity
    }
    
    func jump(){
        
    }
    
    // Run when moving to scene
    override func didMove(to view: SKView) {
        configureMotion()
        configurePhysics()
        configureCube()
        
        self.addChild(cube)
       
        cube.position = CGPoint(x: view.frame.midX, y: view.frame.midY)
    }
        
    // Run every frame
    override func update(_ currentTime: TimeInterval) {
        guard let accelerometerData = motionManager.accelerometerData else {return} // "guard let" is like "if-let" but fail logic goes in block
       
        // Get acceleration
        let xTilt = accelerometerData.acceleration.x
        let yTilt = accelerometerData.acceleration.y // Have spiky platforms on bottom we must tilt DOWN from!!!
        
        let dx = xTilt * xTiltSensitivity
        let dy = yTilt * yTiltSensitivity
      
        guard let physicsBody = cube.physicsBody else {return}
        
        // Move the cube using it
        physicsBody.velocity.dx = dx;
        
        if (dy < 0){
            // physicsBody.velocity.y += dy // Apply down tilt only
        }
        
        physicsBody.velocity.dy = gravity; // TODO: Make acceleration-based; use physics body?
        
        if (cube.position.y <= 0){
            cube.position.y = 0;
            jump();
        }
    }
}
