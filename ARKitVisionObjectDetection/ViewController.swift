import UIKit
import SceneKit
import ARKit
import Vision

//global vars
var ageGroups: [String: Int] = ["0-2": 0,
                                "4-6": 1,
                                "8-12": 2,
                                "15-20": 3,
                                "25-32": 4,
                                "38-43": 5,
                                "48-53": 6,
                                "60-100": 7]

var anchors = [AgeAnchor]()

var threshold = 1.0

//ARanchor subclass with # of phones
class AgeAnchor: ARAnchor {
    var phones = 0
}


class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    private var viewportSize: CGSize!
    private var detectRemoteControl: Bool = true
    
    override var shouldAutorotate: Bool { return false }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        
        viewportSize = sceneView.frame.size
    }
    
    // App opens
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTracking()
    }
    // App pauses
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // Happens on start and when they press reset
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
        detectRemoteControl = true
    }

    //Tells the delegate that a SceneKit node corresponding to a new AR anchor has been added to the scene.
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: AgeAnchor) {
        guard anchor.name == "remoteObjectAnchor" else { return }
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
        sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        node.addChildNode(sphereNode)
    }
    
    //Tells the delegate that the renderer has cleared the viewport and is about to render the scene.
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard detectRemoteControl,
            let capturedImage = sceneView.session.currentFrame?.capturedImage
            else { return }
        
        // used code template from Process Detections - TODO: into a function
        
        // set up and perform requests for face rectangle detection
        let faceDetection = VNDetectFaceRectanglesRequest()
        let faceDetectionRequest = VNSequenceRequestHandler()
        try? faceDetectionRequest.perform([faceDetection], on: capturedImage)
        guard let results = faceDetection.results as? [VNFaceObservation] else {
            print("error on face detection results")
            return }
        
        // for each face set up ARkit anchor + detect age
        for observation in results {
           
            guard let currentFrame = sceneView.session.currentFrame else { continue }
            print("observations")
            let fromCameraImageToViewTransform = currentFrame.displayTransform(for: .portrait, viewportSize: viewportSize)
            let boundingBox = observation.boundingBox
            let viewNormalizedBoundingBox = boundingBox.applying(fromCameraImageToViewTransform)
            let t = CGAffineTransform(scaleX: viewportSize.width, y: viewportSize.height)
            // Scale up to view coordinates
            let viewBoundingBox = viewNormalizedBoundingBox.applying(t)

            let midPoint = CGPoint(x: viewBoundingBox.midX,
                       y: viewBoundingBox.midY)

            let results = sceneView.hitTest(midPoint, types: .featurePoint)
            guard let result = results.first else { continue }
            
            let anchor = AgeAnchor(name: "person", transform: result.worldTransform)
            
            
            //detectRemoteControl = false
            
            // get current frame
            let image = CIImage(cvPixelBuffer: capturedImage)
            var ageBin:String = ""
            // create handler for age detection, pass the image cropped to face bounding box
            let imageRequestHandler = VNImageRequestHandler(ciImage: image.cropped(to: observation.boundingBox))
            do {
                // perform age detection
                try imageRequestHandler.perform([ageDetectionRequest])
                guard let results = ageDetectionRequest.results else {return}
                var confidence:Float = 0

                
                // iterate over age bins for one observtaion and find highest confidence
                for item in results where item is VNClassificationObservation {
                    let item2 = item as? VNClassificationObservation
                    guard let confidence2 = item2?.confidence else {continue}
                    if confidence2 > confidence {
                        confidence = confidence2
                        guard let ageBin2 = item2?.identifier else {continue}
                        ageBin = ageBin2
                    }
                }
                
            } catch {
                print("Failed to perform age detection request.")
            }
            anchor.phones = ageGroups[ageBin] ?? 0
            // check distance from existing anchors
            for anchorItem in anchors {
                let location = simd_make_float3(anchorItem.transform.columns.3)
            }
            //TODO : add only if there isnt an anchor around those coords
            sceneView.session.add(anchor: anchor)
            anchors.append(anchor)
            print("success")
        }
        
        
        
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: capturedImage, orientation: .leftMirrored, options: [:])
//
//        do {
//            try imageRequestHandler.perform([objectDetectionRequest])
//        } catch {
//            print("Failed to perform object request.")
//        }
//
        
    }
    
    // set up age detection request
    lazy var ageDetectionRequest: VNCoreMLRequest = {
        guard let model = try? VNCoreMLModel(for: AgeNet(configuration: MLModelConfiguration()).model) else {
             fatalError("Erro acessando modelo")
        }

        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation], let gendResult = results.first else {
                  fatalError("Unexpected type!")
            }
            
        }
        return request
    }()
    
//    lazy var objectDetectionRequest: VNCoreMLRequest = {
//            guard let model = try? VNCoreMLModel(for: YOLOv3TinyInt8LUT(configuration: MLModelConfiguration()).model) else{
//                 fatalError("Erro acessando modelo")
//            }
//
//            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
//                self?.processDetections(for: request, error: error)
//            }
//            return request
//    }()
//
    
//    func processDetections(for request: VNRequest, error: Error?) {
//        guard error == nil else {
//            print("Object detection error: \(error!.localizedDescription)")
//            return
//        }
//
//        guard let results = request.results else { return }
//
//        for observation in results where observation is VNRecognizedObjectObservation {
//            guard let objectObservation = observation as? VNRecognizedObjectObservation,
//                let topLabelObservation = objectObservation.labels.first,
//                topLabelObservation.identifier == "remote",
//                topLabelObservation.confidence > 0.9
//                else { continue }
//
//            guard let currentFrame = sceneView.session.currentFrame else { continue }
//
//            // Get the affine transform to convert between normalized image coordinates and view coordinates
//            let fromCameraImageToViewTransform = currentFrame.displayTransform(for: .portrait, viewportSize: viewportSize)
//            // The observation's bounding box in normalized image coordinates
//            let boundingBox = objectObservation.boundingBox
//            // Transform the latter into normalized view coordinates
//            let viewNormalizedBoundingBox = boundingBox.applying(fromCameraImageToViewTransform)
//            // The affine transform for view coordinates
//            let t = CGAffineTransform(scaleX: viewportSize.width, y: viewportSize.height)
//            // Scale up to view coordinates
//            let viewBoundingBox = viewNormalizedBoundingBox.applying(t)
//
//            let midPoint = CGPoint(x: viewBoundingBox.midX,
//                       y: viewBoundingBox.midY)
//
//            let results = sceneView.hitTest(midPoint, types: .featurePoint)
//            guard let result = results.first else { continue }
//
//            let anchor = AgeAnchor(name: "remoteObjectAnchor", transform: result.worldTransform)
//
//            sceneView.session.add(anchor: anchor)
//            //detectRemoteControl = false
//        }
//    }
    
    @IBAction private func didTouchResetButton(_ sender: Any) {
        resetTracking()
    }
}
