//
//  CollectionVC.swift
//  Flickr
//
//  Created by matt_spb on 01.03.2020.
//  Copyright © 2020 matt_spb_dev. All rights reserved.
//

import UIKit
import SwiftyJSON

// надо как то сделать красиво, чтобы во время пул ту  рефреш поялвялся только верхний активити индикатор
// в общем нужно положить индикатор в хедер и футер таблицы и убрать с центра экрана

class CollectionVC: BaseVC {
    
    var dataSource = [PhotoModel]()
    var page = 1
    var shouldShowLoadingCell = false
    var hasMorePhotos = true
    
    let refreshControl: UIRefreshControl = {
        let refControl = UIRefreshControl()
        refControl.addTarget(self, action: #selector(refresh(sender:)), for: .valueChanged)
        return refControl
    }()

    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        configureCollectionView()
        loadPhotos()
        setupActivityIndicatior()
        loaderView?.startAnimation()
    }
    
    @objc private func refresh(sender: UIRefreshControl) {
        page = 1
        loadPhotos(refresh: true)
        sender.endRefreshing() //дернуть когда придут данные
    }
    
    private func configureCollectionView() {
        collectionView.register(cellType: PhotoCell.self)
        collectionView.refreshControl = refreshControl
        collectionView.delegate = self
        collectionView.dataSource = self
    } 
}

extension CollectionVC: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: PhotoCell.self) 
        let photo = dataSource[indexPath.row]
        cell.configure(with: photo)
        
        if indexPath.row == dataSource.count - 1 && hasMorePhotos {
            page += 1
            loadPhotos()
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photoModel = dataSource[indexPath.row]
        guard let destVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(identifier: "DetailVC") as? DetailPhotoVC else { return }
        destVC.photoModel = photoModel
        navigationController?.pushViewController(destVC, animated: true)
    }
    
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let offsetY         = scrollView.contentOffset.y
        let contentHeight   = scrollView.contentSize.height
        let height          = scrollView.frame.size.height
        
        if offsetY > contentHeight - height {
            guard hasMorePhotos else { return }
            // здесь добавить нижний пул ту рефреш
            fetchNextPage()
        }
    }
    
    private func fetchNextPage() {
        page += 1
        loadPhotos()
    }
    
    
    private func isLoadingIndexPath(_ indexPath: IndexPath) -> Bool {
        guard shouldShowLoadingCell else { return false }
        return indexPath.row == self.dataSource.count
    }
}

extension CollectionVC: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (UIScreen.main.bounds.width - 20) / 3 
        return CGSize(width: width, height: width)
    }
}

// MARK: - Networking

extension CollectionVC {
    
    func loadPhotos(refresh: Bool = false) {
        print("Fetching page \(page), refresh: \(refresh)")
        loaderView?.startAnimation()
        
        APIWrapper.getFullInfoPhoto(page: page, per_page: Const.Screen.collection.per_page, success: { [weak self] response in
            
            guard let self = self else { return }
            
            let json = JSON(response)
            let photosArray = json["photos"]["photo"].arrayValue

            if refresh {
                self.dataSource = []
                for jsonPhoto in photosArray {
                    let photo = PhotoModel(json: jsonPhoto)
                    let user = User(with: jsonPhoto)
                    self.configureUser(user: user)
                    photo.user = user
                    self.dataSource.append(photo)
                }
                print("count = \(self.dataSource.count)")
            } else {
                for jsonPhoto in photosArray {
                    let photo = PhotoModel(json: jsonPhoto)
                    if !self.dataSource.contains(photo) {
                        let user = User(with: jsonPhoto)
                        self.configureUser(user: user)
                        photo.user = user
                        self.dataSource.append(photo)
                    }
                }
                print("count = \(self.dataSource.count)")
            }
                                    
            let pages = json["photos"]["pages"].intValue
            self.shouldShowLoadingCell = self.page < pages
            
            DispatchQueue.main.async {
                self.loaderView?.stopAnimation()
                self.collectionView.reloadData()
            }
   
        }) { (error) in
            print("error")
        }
    }
    
    private func configureUser(user: User) {
        guard user.iconServer > 0 else { return }
        APIWrapper.getUserNsid(for: user.id) { result in
            switch result {
                case .success(let nsid):
                    DispatchQueue.main.async {
                        let userPicUrl = "http://farm\(user.iconFarm).staticflickr.com/\(user.iconServer)/buddyicons/\(nsid).jpg"
                        user.nsid = nsid
                        user.userPicUrl = userPicUrl
                }
                
                case .failure(let error):
                    print(error.rawValue)
            }
        }
    }
}

