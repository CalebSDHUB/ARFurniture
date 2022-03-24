//
//  ViewController.swift
//  FurnitureAR
//
//  Created by Caleb Danielsen on 11/03/2022.
//

import UIKit
import SceneKit
import ARKit
import MBProgressHUD

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    private var hud: MBProgressHUD!
    
    private var newAngleY: Float = 0.0
    private var currentAngleY: Float = 0.0
    private var localTranslatePosition: CGPoint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        sceneView.debugOptions = [SCNDebugOptions.showBoundingBoxes]
        
        sceneView.autoenablesDefaultLighting = true
        
        hud = MBProgressHUD.showAdded(to: sceneView, animated: true)
        hud.label.text = "Detecting plane..."
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        registerGestureRecognizers()
    }
    
    private func centerPivot(node: SCNNode) {
        
        let (cX, cZ) = computeCenterOfNodeXZArea(node: node)
        
        node.pivot.m41 = cX
        node.pivot.m43 = cZ
        
        /*
         
         Matrix structure:
         
         [m11 m12 m13 m14]
         [m21 m22 m23 m24]
         [m31 m32 m33 m34]
         [m41 m42 m43 m44]
         
         Matrix definition:
         
         [1 0 0 0]
         [0 1 0 0]
         [0 0 1 0]
         [x y z 1]
         
         */
        
    }
    
    private func computeCenterOfNodeXZArea(node: SCNNode) -> (cX: Float, cZ: Float) {
        
        // Compute the boundingBox of the bottom area of the chair
        
        let min = node.boundingBox.min
        let max = node.boundingBox.max
        let width = CGFloat(max.x - min.x)
        let deepth = CGFloat(max.z - min.z)
        let centerX = width / 2
        let centerZ = deepth / 2
        
        return (Float(centerX), Float(centerZ))
    }
    
    private func registerGestureRecognizers() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
        sceneView.addGestureRecognizer(pinchGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
        sceneView.addGestureRecognizer(panGestureRecognizer)
        
        let longGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        
        sceneView.addGestureRecognizer(longGestureRecognizer)
    }
    
    @objc private func tapped(recognizer: UITapGestureRecognizer) {
        guard let sceneView = recognizer.view as? ARSCNView else { return }
        let touch = recognizer.location(in: sceneView)
        
        let hitTestResults = sceneView.hitTest(touch, types: .existingPlane)
        
        // Add object to scene
        if let hitTest = hitTestResults.first {
            let chairScene = SCNScene(named: "art.scnassets/chair.dae")!
            guard let chairNode = chairScene.rootNode.childNode(withName: "chairNode", recursively: true) else { return }
            chairNode.position = SCNVector3(hitTest.worldTransform.columns.3.x, hitTest.worldTransform.columns.3.y, hitTest.worldTransform.columns.3.z)
            
            centerPivot(node: chairNode)
            
            sceneView.scene.rootNode.addChildNode(chairNode)
        }
    }
    
    
    
    @objc private func pinched(recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .changed {
            guard let sceneView = recognizer.view as? ARSCNView else { return }
            let touch = recognizer.location(in: sceneView)
            
            let hitTestResults = sceneView.hitTest(touch, options: nil)
            
            if let hitTest = hitTestResults.first {
                let chairNode = hitTest.node
                
                let pinchScaleX = Float(recognizer.scale) * chairNode.scale.x
                let pinchScaleY = Float(recognizer.scale) * chairNode.scale.y
                let pinchScaleZ = Float(recognizer.scale) * chairNode.scale.z
                
                chairNode.scale = SCNVector3(pinchScaleX, pinchScaleY, pinchScaleZ)
                recognizer.scale = 1
            }
        }
    }
    
    @objc private func panned(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .changed {
            guard let sceneView = recognizer.view as? ARSCNView else { return }
            
            let touch = recognizer.location(in: sceneView)
            let translation = recognizer.translation(in: sceneView)
            let hitTestResults = sceneView.hitTest(touch, options: nil)
            
            if let hitTest = hitTestResults.first {
                let chairNode = hitTest.node
                
                // The amount of moving the finger left of right (translation x) is mapped into the rotation (euler-angle y).
                newAngleY = Float(translation.x) * (Float) (Double.pi / 180) // rad -> deg
                newAngleY += currentAngleY
                chairNode.eulerAngles.y = newAngleY
            }
        }
        
        if recognizer.state == .ended { currentAngleY = newAngleY }
    }
    
    @objc private func longPressed(recognizer: UILongPressGestureRecognizer) {
        
        let factor: CGFloat = 700.0
        
        guard let sceneView = recognizer.view as? ARSCNView else { return }
        
        let touch = recognizer.location(in: sceneView)
        
        let hitTestResults = sceneView.hitTest(touch, options: nil)
        
        if let hitTest = hitTestResults.first {
            let chairNode = hitTest.node
            print("Node \(chairNode)")
            
            if recognizer.state == .began {
                localTranslatePosition = touch
            } else if recognizer.state == .changed {
                let deltaX = (touch.x - localTranslatePosition.x) / factor
                let deltaY = (touch.y - localTranslatePosition.y) / factor
                
                chairNode.localTranslate(by: SCNVector3(deltaX, 0.0, deltaY))
                localTranslatePosition = touch
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        // Detected a plane
        if anchor is ARPlaneAnchor {
            DispatchQueue.main.async { [weak self] in
                self?.hud.label.text = "Plane detected"
                self?.hud.hide(animated: true, afterDelay: 1.0)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
}
