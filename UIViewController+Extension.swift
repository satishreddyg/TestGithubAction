//
//  UIViewController+Extension.swift
//  RadioTrax
//
//  Created by Chris on 2020-07-09.
//  Copyright © 2020 Cognosos. All rights reserved.
//

extension UIViewController {
    // Get ViewController in top present level
      var topPresentedViewController: UIViewController? {
          var target: UIViewController? = self
          while (target?.presentedViewController != nil) {
              target = target?.presentedViewController
          }
          return target
      }
      
      // Get top VisibleViewController from ViewController stack in same present level.
      // It should be visibleViewController if self is a UINavigationController instance
      // It should be selectedViewController if self is a UITabBarController instance
      var topVisibleViewController: UIViewController? {
          if let navigation = self as? UINavigationController {
              if let visibleViewController = navigation.visibleViewController {
                  return visibleViewController.topVisibleViewController
              }
          }
          if let tab = self as? UITabBarController {
              if let selectedViewController = tab.selectedViewController {
                  return selectedViewController.topVisibleViewController
              }
          }
          return self
      }
      
      // Combine both topPresentedViewController and topVisibleViewController methods, to get top visible viewcontroller in top present level
      var topMostViewController: UIViewController? {
          return self.topPresentedViewController?.topVisibleViewController
      }
      
      func showToast(with message: String) {
          let containerView = UIView()
          let toastLabel = UILabel()
          toastLabel.textColor = .white
          toastLabel.font = UIFont.systemFont(ofSize: 15)
          toastLabel.text = message
          toastLabel.numberOfLines = 0
          containerView.alpha = 1.0
          containerView.layer.cornerRadius = 10;
          containerView.clipsToBounds  =  true
          containerView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
          containerView.addSubview(toastLabel)
          view.addSubview(containerView)
          
          containerView.translatesAutoresizingMaskIntoConstraints = false
          toastLabel.translatesAutoresizingMaskIntoConstraints = false
          let topAnchorConstant = abs(100 - view.frame.minY)
          NSLayoutConstraint.activate([
              toastLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
              toastLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
              toastLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
              toastLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
              
              containerView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15),
              containerView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -15),
              containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: topAnchorConstant),
              containerView.heightAnchor.constraint(equalToConstant: 40),
          ])
          
          UIView.animate(withDuration: 0.5, delay: 3.0, options: .curveEaseOut, animations: {
              containerView.alpha = 0.0
          }, completion: { _ in
              containerView.removeFromSuperview()
          })
      }
      
      func showAlert(withTitle title: String, andMessage message: String, andDefaultTitle defaultTitle: String, andCustomActions actions: [UIAlertAction]? = nil) {
          let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
          if let customActions = actions {
              customActions.forEach({[weak alertController] in
                  alertController?.addAction($0)})
          }
          let defaultAction = UIAlertAction(title: defaultTitle, style: actions == nil ? .cancel : .default, handler: nil)
          alertController.addAction(defaultAction)
          DispatchQueue.main.async {
              self.present(alertController, animated: true, completion: nil)
          }
      }
    
    // MARK:- API's
    
    func checkToShowPlaceholderImage(on mapView: GMSMapView) {
        var zonesArray: [ZoneModel]?
        do {
            zonesArray = try USER_DEFAULT.getCustomObject(forKey: "layoutZones", castTo: [ZoneModel].self)
        } catch {
            print(error.localizedDescription)
        }
        if let zones = zonesArray,
            !zones.isEmpty {
            for zone in zones {
                guard zone.perimeters.count > 0,
                    let overlayImage = zone.overlayImage,
                    let urlString = overlayImage.publicUrl,
                    let layoutURL = URL(string: urlString) else { continue }
                
                let southWestLatitude = overlayImage.bottomRightX ?? zone.perimeters[2].latitude
                let southWestLongitude = overlayImage.bottomRightY ?? zone.perimeters[2].longitude

                let northEastLatitude = overlayImage.topLeftX ?? zone.perimeters[0].latitude
                let northEastLongitude = overlayImage.topLeftY ?? zone.perimeters[0].longitude
                
                let southWest = CLLocationCoordinate2D(latitude: southWestLatitude, longitude: southWestLongitude)
                let northEast = CLLocationCoordinate2D(latitude: northEastLatitude, longitude: northEastLongitude)
                let overlayBounds = GMSCoordinateBounds(coordinate: southWest, coordinate: northEast)

                if let dict = USER_DEFAULT.getObject(forKey: "generalMotorPlantImageDict") as? [String: Data],
                    let data = dict[layoutURL.absoluteString],
                    let icon = UIImage(data: data),
                    mapView.mapType == .satellite {
                    let overlay = GMSGroundOverlay(bounds: overlayBounds, icon: icon)
                    overlay.bearing = overlayImage.rotation ?? 0
                    overlay.map = mapView
                    overlay.zIndex = 0
                } else {
                    downloadImage(from: layoutURL) { icon in
                        guard mapView.mapType == .satellite else { return }
                        onMainAsync {
                            let overlay = GMSGroundOverlay(bounds: overlayBounds, icon: icon)
                            overlay.bearing = overlayImage.rotation ?? 0
                            overlay.map = mapView
                            overlay.zIndex = 0
                        }
                    }
                }
            }
        } else {
            fetchZoneLayouts()
        }
    }
    
    func fetchZoneLayouts() {
        ApiClient.shared.fetchZoneWithLayouts { [weak self] (responseObject, error) in
            guard error == nil else { return }
            self?.handleResponse(with: responseObject)
        }
    }
    
    private func handleResponse(with zonesArray: [ZoneModel]?, onMap mapView: GMSMapView? = nil) {
        if let zones = zonesArray {
            do {
                try USER_DEFAULT.setCustomObject(zones, forKey: "layoutZones")
            } catch let error {
                print("error is: \(error)")
            }
            for zone in zones {
                guard zone.perimeters.count > 0,
                    let overlayImage = zone.overlayImage,
                    let urlString = overlayImage.publicUrl,
                    let layoutURL = URL(string: urlString) else { continue }
                
                let southWestLatitude = overlayImage.bottomRightX ?? zone.perimeters[2].latitude
                let southWestLongitude = overlayImage.bottomRightY ?? zone.perimeters[2].longitude
                
                let northEastLatitude = overlayImage.topLeftX ?? zone.perimeters[0].latitude
                let northEastLongitude = overlayImage.topLeftY ?? zone.perimeters[0].longitude
                
                let southWest = CLLocationCoordinate2D(latitude: southWestLatitude, longitude: southWestLongitude)
                let northEast = CLLocationCoordinate2D(latitude: northEastLatitude, longitude: northEastLongitude)
                let overlayBounds = GMSCoordinateBounds(coordinate: southWest, coordinate: northEast)
                downloadImage(from: layoutURL) { icon in
                    guard let _mapView = mapView,
                        _mapView.mapType == .satellite else { return }
                    onMainAsync {
                        let overlay = GMSGroundOverlay(bounds: overlayBounds, icon: icon)
                        overlay.bearing = overlayImage.rotation ?? 0
                        overlay.map = _mapView
                        overlay.zIndex = 0
                    }
                }
            }
        } else {
            do {
                try USER_DEFAULT.setCustomObject([ZoneModel](), forKey: "layoutZones")
            } catch let error {
                print("error is: \(error)")
            }
        }
    }
        
    func downloadImage(from url: URL, completion: @escaping (UIImage?) -> ()) {
        getData(from: url) { data, response, error in
            guard let data = data, error == nil,
                let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            USER_DEFAULT.setObject([url.absoluteString: UIImagePNGRepresentation(image)], forKey: "generalMotorPlantImageDict")
            completion(image)
        }
    }
    
    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
}
