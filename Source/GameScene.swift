import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    let player = SKSpriteNode(imageNamed: "citronaut_0")
    var playerXScale: CGFloat = 1 // We will flip this value so we need to cache the original one
    
    let platform = SKSpriteNode(color: UIColor(cgColor: CGColor(gray: 1, alpha: 1)), size: CGSize(width: 10000, height: 10)) // Temporary invis. platform to test jumping
  
    let cam = SKCameraNode()
    
    let jumpSound = SKAudioNode(fileNamed: "jump.wav")
    let landSound = SKAudioNode(fileNamed: "land.wav")

    let motionManager = CMMotionManager()
    let xTiltSensitivity: CGFloat = 500
    let yTiltSensitivity: CGFloat = 0
  
    func configureCamera(){
        // Bind camera node to scene
        self.camera = cam
        self.addChild(cam) // MARK: Why does it make sense to child it?
    }
    
    func configureMotion(){
        // Start accelerometer
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.02 // 50 updates per secon
            motionManager.startAccelerometerUpdates()
        }
    }
  
    func configureSounds(){
        // Make sure sounds don't loop
        jumpSound.autoplayLooped = false;
        landSound.autoplayLooped = false;
        
        // Add sound nodes to scene
        addChild(jumpSound)
        addChild(landSound)
    }
    
    func configurePlayer(){
        // Scale player to reasonable size
        player.setScale(5.0)
        
        // Cache applied x scale
        playerXScale = player.xScale;

        // Set pos
        player.position = CGPoint(x: frame.midX, y: frame.midY) // Middle of screen

        // Load walk textures
        let walkTextures: [SKTexture] = [
            SKTexture(imageNamed: "citronaut_0"),
            SKTexture(imageNamed: "citronaut_1")
        ]
      
        // Make sure they use nearest neighbor resizing
        for texture in walkTextures {
            texture.filteringMode = .nearest;
        }
       
        // Create walk animation using textures
        let walkAnimation = SKAction.animate(
            with: walkTextures,
            timePerFrame: 0.25 // 4 FPS
        )
        
        // Run it on player
        player.run(SKAction.repeatForever(walkAnimation))
        
        // Setup player physics body
        let physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: player.frame.width, height: player.frame.height))
        
        physicsBody.isDynamic = true // Apply updates
        physicsBody.usesPreciseCollisionDetection = true;
        physicsBody.contactTestBitMask = 2 // Collide w/platform
        physicsBody.categoryBitMask = 1 // TODO: Add some layer of organization to this
        physicsBody.linearDamping = 0

        player.physicsBody = physicsBody
            
        // Add player to scene
        self.addChild(player)
    }
 
    func configurePlatforms(){
        // MARK: Temporary, test platform for player; idea is to have many
        
        platform.position = CGPoint(x: frame.midX, y: frame.minY + 50) // Place platform just offscreen
      
        let platformBody = SKPhysicsBody(rectangleOf: platform.size)
        
        platformBody.isDynamic = false // Apply physics updates
        platformBody.affectedByGravity = false
        platformBody.contactTestBitMask = 1 // Collide w/player
        platformBody.categoryBitMask = 2 // TODO: Add some layer of organization to this
        
        platform.physicsBody = platformBody
        
        self.addChild(platform)
    }
    
    func configureScenePhysics(){
        self.physicsWorld.contactDelegate = self // Make contact tests take place in this scene
        self.physicsWorld.gravity = CGVector(dx: 0, dy: -9.81) // Remove global gravity
    }
  
    func jump(){
        guard let physicsBody = player.physicsBody else {return}
        
        physicsBody.velocity = CGVector.zero
        physicsBody.applyImpulse(CGVector(dx: 0, dy: 400)) // 400 dy is perfect!
        
        jumpSound.run(SKAction.play())
    }
   
    func createPlatform(at position: CGPoint) -> SKSpriteNode {
        // Platforms should all have same width, height
        let platformWidth = player.size.width + (1/2 * player.size.width) // Player's width + 1/4 that width on both sides (so add 1/2 width of player)
        let platformHeight = player.size.height * (1/10) // Tenth of player's height

        let platform = SKSpriteNode(
            color: UIColor(cgColor: CGColor(gray: 1, alpha: 1)),
            size: CGSize(width: platformWidth, height: platformHeight)
        )
        
        // Leave normal anchorpoint (center)
        
        return platform
    }
    
    // Run when moving to scene
    override func didMove(to view: SKView) {
        configureCamera()
        configureMotion()
        configureSounds()
        configureScenePhysics() // Physics environment only, not individual physics bodies!
        configurePlayer()
        configurePlatforms()
    }
    
    func isBodyOf(_ target: SKSpriteNode, _ body: SKPhysicsBody) -> Bool {
        // Check if given sprite node's physics body has the same cat. bitmask (type) as given body
        // In short, does body belong to the target node?
        guard let targetCategoryBitmask = target.physicsBody?.categoryBitMask else {return false}
       
        return body.categoryBitMask == targetCategoryBitmask
    }

    // Run on collision contact taking place
    func didBegin(_ contact: SKPhysicsContact) {
        // Get the bodies
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
      
        // Check which body is the player
        let playerIsBodyA = isBodyOf(player, bodyA)
        let playerIsBodyB = isBodyOf(player, bodyB)

        // All collisions should involve the player; if neither body is player, abort
        if !playerIsBodyA && !playerIsBodyB {
            return
        }

        // Track the other body
        var otherBody = {
            if (playerIsBodyA){
                return bodyB;
            } else {
                return bodyA;
            }
        }()
        
        // Run collision logic here :)
        
        landSound.run(SKAction.play())
        
        jump()
    }

    // Run every frame
    override func update(_ currentTime: TimeInterval) {
        // Keep cam on player
        
        // Ensure camera moves up only if the player has passed its current position (doodle jump effect!)
        if player.position.y > cam.position.y {
            cam.position.y = player.position.y
        }
      
        // Start with 2 contiguous screen heights
        // Everytime the player passes a screen height worth of level, instantiate 1 more screen height
        // Instantiate platforms within this screen height
        
        // Apply tilt to player body
        if let playerBody = player.physicsBody {
            // Get accelerometer data
            guard let accelerometerData = motionManager.accelerometerData else {return} // "guard let" is like "if-let" but fail logic goes in block
           
            // Get acceleration from it
            let xTilt = accelerometerData.acceleration.x
            let yTilt = accelerometerData.acceleration.y // Have spiky platforms on bottom we must tilt DOWN from!!!
            
            let dx = xTilt * xTiltSensitivity
            let dy = yTilt * yTiltSensitivity
            
            playerBody.velocity.dx = dx
         
            // Flip if going the other way, MARK: restructure code so accel. data is independent...
            if (dx < 0){
                player.xScale = -playerXScale
            } else {
                player.xScale = playerXScale
            }
        }
    }
}
