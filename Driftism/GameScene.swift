//
//  GameScene.swift
//  Driftism
//
//  Created by Cyrus Liu on 3/13/17.
//  Copyright © 2017 Cyrus Liu. All rights reserved.
//

import SpriteKit
import GameplayKit
import Darwin

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
func ^^ (radix: Double, power: Double) -> Double {
    return pow(Double(radix), Double(power))
}

class GameScene: SKScene {
    
    let steerStick =  🕹(diameter: 200), throttleStick =  🕹(diameter: 200)

    private var carBody : SKNode?, wheelFL : SKNode?, wheelFR : SKNode?, wheelRR : SKNode?, wheelRL : SKNode?
    
    private var smoke : SKEmitterNode?
    
    private var cam: SKCameraNode?
    
    private var x: [Double] = []
    
    private var m: Double = 0.0, L: Double = 0.0, a: Double = 0.0, b: Double = 0.0, G_f: Double = 0.0, G_r: Double = 0.0, C_a: Double = 0.0, C_x: Double = 0.0, I_z: Double = 0.0, mu: Double = 0.0, mu_s: Double = 0.0, scaleFactor: Double = 0.0
    
    private var lastUpdateTime : TimeInterval?
    
    private var sceneCreated : Bool = false
    
    override func didMove(to view: SKView) {
        if !sceneCreated {
            createScene()
        }
    }
    
    func createScene() {
        self.x = Array(repeating: 0.0, count:6)
        
        // Get carBody node from scene and store it for use later
        self.carBody = self.childNode(withName: "carBody")
        
        self.wheelFL = self.carBody?.childNode(withName: "wheelFL")
        self.wheelFR = self.carBody?.childNode(withName: "wheelFR")
        self.wheelRR = self.carBody?.childNode(withName: "wheelRR")
        self.wheelRL = self.carBody?.childNode(withName: "wheelRL")
        
        setCarParam(m: 2010, L: 2.45, a: 1.47, C_a: 1200000, C_x: 200000, I_z: 3994, mu: 0.75, mu_s: 0.6)
        
        
        
        if let carBody = self.carBody {
            carBody.alpha = 0.0
            carBody.run(SKAction.fadeIn(withDuration: 2.0))
        }
        
        self.smoke = SKEmitterNode(fileNamed: "tireSmoke.sks")
//        smoke?.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0.2, 0.4, 0.0],
//                                                          times: [0.0, 0.2, 1])
        
        smoke?.position = CGPoint(x:-180, y: 0)
        smoke?.targetNode = self
        carBody?.addChild(smoke!)
        
        let traceFL = newTraceEmitter()
        let traceFR = newTraceEmitter()
        let traceRR = newTraceEmitter()
        let traceRL = newTraceEmitter()
        
        wheelFL?.addChild(traceFL!)
        wheelFR?.addChild(traceFR!)
        wheelRL?.addChild(traceRR!)
        wheelRR?.addChild(traceRL!)
        
        
        self.cam = childNode(withName: "cameraNode") as? SKCameraNode
        self.camera = self.cam
        
        steerStick.position = CGPoint(x: self.frame.minX + steerStick.radius + 30, y: self.frame.minY + steerStick.radius + 30)
        steerStick.stick.radius = 100
        steerStick.zPosition = 100
        steerStick.substrate.color = UIColor.darkGray
        steerStick.stick.color = UIColor.gray
        
        throttleStick.position = CGPoint(x: self.frame.maxX - throttleStick.radius - 30, y: self.frame.minY + throttleStick.radius + 30)
        throttleStick.zPosition = 100
        throttleStick.substrate.color = UIColor.darkGray
        throttleStick.stick.color = UIColor.gray
        
        self.cam?.addChild(steerStick)
        self.cam?.addChild(throttleStick)
        
        sceneCreated = true
    }
    
    func newTraceEmitter() -> SKEmitterNode? {
        let trace = SKEmitterNode(fileNamed: "tireTrace.sks")
        trace?.targetNode = self
        trace?.zPosition = -1
        return trace
    }
    
    func setCarParam(m:Double, L:Double, a:Double, C_a:Double, C_x:Double, I_z:Double, mu:Double, mu_s:Double) {
        let g = 9.81
        
        self.m = m
        self.L = L
        self.a = a
        self.b = L-a
        
        self.G_r = m*g*a/L
        self.G_f = m*g*b/L
        
        self.C_a = C_a
        self.C_x = C_x
        self.mu = mu
        self.mu_s = mu_s
        self.I_z = I_z
        
        self.scaleFactor = Double(convert((wheelFL?.position)!, from: carBody!).x - convert((wheelRL?.position)!, from: carBody!).x) / L
    }
    
    func sign(_ a: Double) -> Double{
        return a<0 ? -1:1
    }
    
    func wrapToPi(_ a: Double) -> Double{
        let Pi = Double.pi
        return fmod(a+Pi, 2*Pi) - Pi
    }
    
    func tire(throttle:Double, Ux:Double, alpha_in: Double, Fz:Double) -> (Fx:Double, Fy:Double) {
        var K: Double
        var F: Double
        var Fx: Double
        var Fy: Double
        var rev: Double
        var gamma: Double
        var alpha: Double = alpha_in
        
        let pi = Double.pi
        
        if (throttle == Ux) {
            K = 0
        } else if Ux == 0 {
            Fx = sign(throttle)*mu*Fz
            Fy = 0;
            return (Fx, Fy)
        } else {
            K = (throttle-Ux)/abs(Ux)
        }
        
        rev = 1;
        if K < 0 {
            rev = -1;
            K = abs(K);
        }
        
        if abs(alpha) > pi/2 {
            alpha = (pi-abs(alpha))*sign(alpha)
        }
        
        gamma = sqrt(C_x^^2 * (K/(1+K))^^2 + C_a^^2 * (tan(alpha)/(1+K))^^2);
        
        if gamma <= 3*mu*Fz {
            F = gamma - 1/(3*mu*Fz)*(2-mu_s/mu)*gamma^^2 + 1/(9*mu^^2*Fz^^2)*(1-(2/3)*(mu_s/mu))*gamma^^3
        } else {
            F = mu_s*Fz
        }
        
        if gamma == 0 {
            Fx = 0
            Fy = 0
        } else {
            Fx = C_x / gamma * (K/(1+K)) * F * rev
            Fy = -C_a/gamma * (tan(alpha)/(1+K)) * F
        }
        return (Fx,Fy)
    }
    
    func dynamic(x: inout [Double], u: [Double], dt: Double) {
        let pi = Double.pi
        
        let thr = u[0]
        let delta = u[1]
        
        var pos_x = x[0]
        var pos_y = x[1]
        var pos_phi = x[2]
        var Ux = x[3]
        var Uy = x[4]
        var r = x[5]
        
        var alpha_F: Double
        var alpha_R: Double
        var Fy_F: Double
        var Fx_R: Double
        var Fy_R: Double
        var dUx: Double
        var dUy: Double
        var dr: Double
        var U: Double
        var beta: Double
        
        if Ux == 0 && Uy == 0 {
            alpha_F = 0.0
            alpha_R = 0.0
        }
        else if Ux == 0 {
            alpha_F = pi/2*sign(Uy)-delta
            alpha_R = pi/2*sign(Uy)
        }
        else if Ux < 0 {
            alpha_F = (sign(Uy)*pi)-atan((Uy+a*r)/abs(Ux))-delta
            alpha_R = (sign(Uy)*pi)-atan((Uy-b*r)/abs(Ux))
        }
        else {
            alpha_F = atan((Uy+a*r)/abs(Ux))-delta
            alpha_R = atan((Uy-b*r)/abs(Ux))
        }
        alpha_F = wrapToPi(alpha_F)
        alpha_R = wrapToPi(alpha_R)
        
        (_, Fy_F) = tire(throttle: Ux, Ux: Ux, alpha_in: alpha_F, Fz: G_f)
        (Fx_R, Fy_R) = tire(throttle: thr, Ux: Ux, alpha_in: alpha_R, Fz: G_r)
        
        dr = (a*Fy_F*cos(delta)-b*Fy_R)/I_z
        dUx = (Fx_R-Fy_F*sin(delta))/m+r*Uy
        dUy = (Fy_F*cos(delta)+Fy_R)/m-r*Ux
        
        U = sqrt(Ux^^2+Uy^^2)
        if Ux == 0 && Uy == 0 {
            beta = 0
        } else if Ux == 0 {
            beta = pi/2*sign(Uy)
        } else if Ux < 0 && Uy == 0 {
            beta = pi
        } else if Ux < 0 {
            beta = sign(Uy)*pi-atan(Uy/abs(Ux))
        } else {
            beta = atan(Uy/abs(Ux))
        }
        beta = wrapToPi(beta)
        
        pos_x = pos_x + U*cos(beta+pos_phi)*dt*scaleFactor
        pos_y = pos_y + U*sin(beta+pos_phi)*dt*scaleFactor
        pos_phi = pos_phi + r*dt
        Ux = Ux + dUx*dt
        Uy = Uy + dUy*dt
        r = r + dr*dt
    
        x = [pos_x, pos_y, pos_phi, Ux, Uy, r]
    }
    
    
    func touchDown(atPoint pos : CGPoint) {
    }
    
    func touchMoved(toPoint pos : CGPoint) {
    }
    
    func touchUp(atPoint pos : CGPoint) {
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.cam?.run(SKAction.move(to: CGPoint(x:self.x[0], y:self.x[1]), duration: 0.5))
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        self.cam?.run(SKAction.move(to: CGPoint(x:self.x[0], y:self.x[1]), duration: 0.5))
        
        smoke?.emissionAngle = (carBody?.zRotation)!
        let steer = -steerStick.data.velocity.x * 0.6
        
        let vel = throttleStick.data.velocity.y
        
        let thr = vel>0 ? vel*30 : vel*10
        
        if let lastUpdateTime = self.lastUpdateTime {
            let dt = currentTime - lastUpdateTime
            dynamic(x: &self.x, u: [Double(thr), Double(steer)], dt: dt)
        }
        
        self.lastUpdateTime = currentTime
        
        
        self.carBody?.run(SKAction.sequence([SKAction.move(to: CGPoint(x:self.x[0], y:self.x[1]), duration: 0),SKAction.rotate(toAngle: CGFloat(self.x[2]), duration: 0)]))
        
        self.wheelFL?.run(SKAction.rotate(toAngle: steer, duration: 0))
        self.wheelFR?.run(SKAction.rotate(toAngle: steer, duration: 0))
    }
}
