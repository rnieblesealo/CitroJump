import SpriteKit
import GameplayKit
import CoreMotion

/// GKState with reference to scene
class SceneGKState: GKState {
    weak var scene: GameScene?
    
    init(scene: GameScene){
        self.scene = scene
    }
   
    // Used (by ourselves and the state machine) to verify validity of transition
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return self.scene != nil; // Need a scene to move states; changing state entirely changes in-scene stuff!
    }
}

class Title: SceneGKState {
    // Called when entering state
    override func didEnter(from previousState: GKState?) {
        scene!.shouldAutogeneratePlatforms = false // No platform spawns
    
        // Reset cam position
        scene!.camShouldTrackPlayer = false
        scene!.cam.position = CGPoint.zero
      
        // Make a cute little platform for the player to stand on
        let titlePlatformPos = scene!.relative2ViewPos(relativePos: CGPoint(x: 0.5, y: 0.1))
        let titlePlatform = scene!.createPlatform(at: titlePlatformPos)

        // Position the player onto it
        scene!.positionSpriteNodeRelatively(node: scene!.player, relativePos: CGPoint(x: 0.5, y: 0))
        scene!.player.position.y = titlePlatform.frame.maxY

        // Prevent player from responding to movement inputs
        scene!.playerShouldFlip = false
        scene!.player.physicsBody?.isDynamic = false

        // Move the camera slightly up to make space for the title
        scene!.cam.position.y = scene!.player.position.y + 120 // TODO: Figure out how to make this camera placement relative
       
        // Show title label
        scene!.titleLabel?.isHidden = false
    }
   
    // Called when transitioning to next state
    override func willExit(to nextState: GKState) {
        
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        // Can only move ingame from title
        return super.isValidNextState(stateClass) && stateClass == InGame.self
    }
}

class InGame: SceneGKState {
    override func didEnter(from previousState: GKState?) {
        
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        // Can either lose (game over) or quit to title
        return super.isValidNextState(stateClass) && (stateClass == GameOver.self || stateClass == Title.self)
    }
}

class GameOver: SceneGKState {
    override func didEnter(from previousState: GKState?){
        
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        // Can only go back to title after losing (might want to add some retry functionality)
        return super.isValidNextState(stateClass) && stateClass == Title.self
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    let player = SKSpriteNode(imageNamed: "citronaut_0")
    var playerXScale: CGFloat = 1 // We will flip this value so we need to cache the original one
    var playerShouldFlip = true
   
    var titleLabel: SKSpriteNode?
    
    var bgSand: SKSpriteNode?
    var bgOcean: SKSpriteNode?
    var bgClouds = Array<SKSpriteNode>()

    var platformSpawnBase: Int = 0 // Spawn plats between (platformSpawnBase, platformSpawnBase + view.height)
    var platforms = Array<SKSpriteNode>()
    var shouldAutogeneratePlatforms = true
  
    let cam = SKCameraNode()
    var camShouldTrackPlayer = true
    
    let jumpSound = SKAudioNode(fileNamed: "jump.wav")
    let landSound = SKAudioNode(fileNamed: "land.wav")

    let motionManager = CMMotionManager()
    let xTiltSensitivity: CGFloat = 500
    let yTiltSensitivity: CGFloat = 0

    var stateMachine: GKStateMachine?
    
    func configureStateMachine(){
        self.stateMachine = GKStateMachine(states: [
            Title(scene: self),
            InGame(scene: self),
            GameOver(scene: self)
        ])
       
        // Enter first state by default
        stateMachine!.enter(Title.self) // Note: .self explicitly returns the type of the given type
    }
    
    func configureCamera(){
        // Bind camera node to scene
        self.camera = cam
        addChild(cam) // MARK: Why does it make sense to child it?
     
        // Initially center over player
        cam.position.x = player.position.x
    }
  
    func createStaticSpriteNode(imageName: String, relativePos: CGPoint, scale: CGFloat, anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> SKSpriteNode {
        let texture = SKTexture(imageNamed: imageName)
        
        texture.filteringMode = .nearest
        
        let node = SKSpriteNode(texture: texture)
        
        node.anchorPoint = anchorPoint
       
        cam.addChild(node)
    
        node.setScale(scale)
            
        if let view = self.view {
            // View runs from -height to +height, calculate rel. pos using this fact
            // MARK: Not the case for positioning sprite nodes not childed to camera... Oh god why
            let minX = -view.frame.width / 2
            let minY = -view.frame.height / 2
           
            node.position = CGPoint(
                x: minX + relativePos.x * view.frame.width,
                y: minY + relativePos.y * view.frame.height
            )
     
            // Why no need to div by scale?
        }
        
        node.zPosition = -999 // Ensure is always above
        
        return node
    }
    
    func configureScene(){
        let guiScale = 6.0
       
        titleLabel = createStaticSpriteNode(imageName: "title", relativePos: CGPoint(x: 0.5, y: 0.65), scale: guiScale)
        
        titleLabel!.zPosition = 999 // Make sure title is above anything else
        
        let bgScale = 3.0
        let bgAnchorPoint = CGPoint(x: 0.5, y: 0)
        
        bgOcean = createStaticSpriteNode(imageName: "ocean", relativePos: CGPoint(x: 0.5, y: 0.01), scale: bgScale, anchorPoint: bgAnchorPoint)
        bgSand = createStaticSpriteNode(imageName: "sand", relativePos: CGPoint(x: 0.5, y: -0.1), scale: bgScale, anchorPoint: bgAnchorPoint)
       
        // Manual rel. pos for all clouds
        let cloudPositions: [CGPoint] = [
            CGPoint(x: 0.6, y: 0.7),
            CGPoint(x: 0.9, y: 0.95),
            CGPoint(x: 0.15, y: 0.50),
            CGPoint(x: 0.06, y: 0.8),
            CGPoint(x: 0.85, y: 0.38),
        ]
        
        for pos in cloudPositions {
            bgClouds.append(createStaticSpriteNode(imageName: "cloud", relativePos: CGPoint(x: pos.x, y: pos.y), scale: bgScale))
        }
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
        
        player.anchorPoint = CGPoint(x: 0.5, y: 0) // Midbottom

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
        addChild(player)
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
      
        addChild(platform)

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
 
    /// Returns a given relative pos in view coordinates
    func relative2ViewPos(relativePos: CGPoint) -> CGPoint {
        guard let view = self.view else {return CGPoint(x: 0, y: 0)}
        
        return CGPoint(
            x: view.frame.minX + view.frame.width * relativePos.x,
            y: view.frame.minY + view.frame.height * relativePos.y
        )
    }
    
    func positionSpriteNodeRelatively(node: SKSpriteNode, relativePos: CGPoint, anchorPoint: CGPoint? = nil){
        guard let view = self.view else {return}
     
        if (node.parent != scene){
            print("[WARNING] Relatively positioning sprite node not childed to scene itself will NOT work correctly!")
        }
        
        let originalAnchorPoint = node.anchorPoint
        
        // Use temp anchor point if specified
        if let tempAnchorPoint = anchorPoint {
            node.anchorPoint = tempAnchorPoint
        }
        
        // View runs from -height to +height, calculate rel. pos using this fact
        let minX = view.frame.minX
        let minY = view.frame.minY
       
        node.position = CGPoint(
            x: minX + relativePos.x * view.frame.width,
            y: minY + relativePos.y * view.frame.height
        )
       
        // Revert to original anchor point
        node.anchorPoint = originalAnchorPoint
    }

    // Run when moving to scene
    override func didMove(to view: SKView) {
        self.backgroundColor = UIColor(cgColor: CGColor(red: 25 / 255, green: 138 / 255, blue: 255/255, alpha: 1))
       
        configureMotion()
        configureSounds()
        configureScenePhysics() // Physics environment only, not individual physics bodies!
        configurePlayer()
        configureCamera()
        configureScene()
        configureStateMachine()
        
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
        if camShouldTrackPlayer,
           player.position.y > cam.position.y {
            cam.position.y = player.position.y
        }
        
        // Spawn platforms and update spawn base when crossed
        if view != nil && Int(player.position.y + view!.bounds.height) >= platformSpawnBase {
            if shouldAutogeneratePlatforms {
                generatePlatforms(beginAt: platformSpawnBase, endAt: platformSpawnBase + Int(view!.bounds.height))
            }
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
            
            let dx = xTilt * xTiltSensitivity
            
            playerBody.velocity.dx = dx
         
            // Flip if going the other way, MARK: restructure code so accel. data is independent...
            if playerShouldFlip,
               dx < 0 {
                player.xScale = -playerXScale
            } else {
                player.xScale = playerXScale
            }
        }
    }
}
