import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    let player = SKSpriteNode(imageNamed: "citronaut_0")
    var playerXScale: CGFloat = 1 // We will flip this value so we need to cache the original one
    
    var platformSpawnBase: Int = 0 // Spawn plats between (platformSpawnBase, platformSpawnBase + view.height)
    var platforms = Array<SKSpriteNode>()
  
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
     
        // Initially center over player
        cam.position.x = player.position.x
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
        player.setScale(3.0)
        
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
        let playerBody = SKPhysicsBody(rectangleOf: CGSize(width: player.frame.width, height: player.frame.height))
        
        playerBody.isDynamic = true// Apply updates
        playerBody.allowsRotation = false;
        playerBody.usesPreciseCollisionDetection = true;
        playerBody.contactTestBitMask = 2 // Collide w/platform
        playerBody.categoryBitMask = 1 // TODO: Add some layer of organization to this
        playerBody.linearDamping = 0

        player.physicsBody = playerBody
           
        // Add player to scene
        self.addChild(player)
        
        print("PLAYER BOUNDS: \(player.frame.size)")
    }

    func configureScenePhysics(){
        self.physicsWorld.contactDelegate = self // Make contact tests take place in this scene
        self.physicsWorld.gravity = CGVector(dx: 0, dy: -9.81) // Remove global gravity
    }
  
    func jump(){
        guard let physicsBody = player.physicsBody else {return}
        
        physicsBody.velocity = CGVector.zero
        physicsBody.applyImpulse(CGVector(dx: 0, dy: 100)) // 400 dy is perfect!
        
        jumpSound.run(SKAction.play())
        landSound.run(SKAction.play())
    }
  
    func disablePlayerCollision(){
        guard let playerBody = player.physicsBody else {return}
        
        playerBody.collisionBitMask = 0
    }
   
    func enablePlayerCollision(){
        guard let playerBody = player.physicsBody else {return}
        
        playerBody.collisionBitMask = 2
    }
    
    func createPlatform(at position: CGPoint) -> SKSpriteNode {
        let platformTexture = SKTexture(imageNamed: "platform")
        
        platformTexture.filteringMode = .nearest
        
        let platform = SKSpriteNode(texture: platformTexture)
        
        platform.setScale(3.0)
   
        platform.position = position // Place platform just offscreen
     
        // Physics setup
        let platformBody = SKPhysicsBody(rectangleOf: platform.size)
       
        platformBody.isDynamic = false // Don't physics updates (contacts will still be reported)
        platformBody.affectedByGravity = false // No gravity
        platformBody.contactTestBitMask = 1 // Collide w/player
        platformBody.categoryBitMask = 2 // TODO: Add some layer of organization to this
        
        platform.physicsBody = platformBody
      
        self.addChild(platform)

        return platform
    }
  
    func generatePlatforms(beginAt yMin: Int, endAt yMax: Int){
        guard let view = self.view else {return}
       
        let platformToPlatformYOffset = 65
        
        for yPos in stride(from: yMin + platformToPlatformYOffset, to: yMax, by: platformToPlatformYOffset) {
            // Get random x pos
            let xPos = Int.random(in: Int(view.bounds.minX)...Int(view.bounds.maxX))
           
            // Make platform!
            platforms.append(createPlatform(at: CGPoint(x: xPos, y: yPos)))
        }
    }
    
    // Run when moving to scene
    override func didMove(to view: SKView) {
        self.backgroundColor = UIColor(cgColor: CGColor(red: 25 / 255, green: 138 / 255, blue: 255/255, alpha: 1))
        
        configureMotion()
        configureSounds()
        configureScenePhysics() // Physics environment only, not individual physics bodies!
        configurePlayer()
        configureCamera()

        // MARK: Test platform generation
        platformSpawnBase = Int(view.bounds.minY)
        generatePlatforms(beginAt: platformSpawnBase, endAt: platformSpawnBase + Int(view.bounds.height))
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

        // Track the player body and the other body
        var playerBody: SKPhysicsBody
        var otherBody: SKPhysicsBody
       
        if (playerIsBodyA){
            playerBody = bodyA;
            otherBody = bodyB
        } else {
            playerBody = bodyA;
            otherBody = bodyB;
        }
      
        if (playerBody.velocity.dy <= 0){
            jump()
        }
    }

    // Run every frame
    override func update(_ currentTime: TimeInterval) {
        // Ensure camera moves up only if the player has passed its current position (doodle jump effect!)
        if player.position.y > cam.position.y {
            cam.position.y = player.position.y
        }
     
        // Spawn platforms and update spawn base when crossed
        if view != nil && Int(player.position.y + view!.bounds.height) >=  platformSpawnBase {
            generatePlatforms(beginAt: platformSpawnBase, endAt: platformSpawnBase + Int(view!.bounds.height))
            platformSpawnBase += Int(view!.bounds.height)
        }
        
        if let playerBody = player.physicsBody {
            // Phase through all platforms unless falling down
            if playerBody.velocity.dy > -5000 { // I have no fucking clue why using fucking -5000 instead of 0 works, but here it is!
                disablePlayerCollision()
            } else {
                enablePlayerCollision()
            }
            
            // Apply tilt to player body

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
