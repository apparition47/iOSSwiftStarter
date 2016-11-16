//
// Created by VIPER
// Copyright (c) 2015 VIPER. All rights reserved.
//

import UIKit
import Kugel
import CoreStore
import Hakuba
import Async
import StatefulViewController

class ListRepoModuleView: UIViewController, StatefulViewController, ListRepoModuleViewProtocol
{
    var presenter: ListRepoModulePresenterProtocol?;
    
    enum ViewState {
        case Empty;
        case Error;
        case Loading;
        case Content;
        
        var value: String {
            switch self {
            case .Empty:
                return "Empty";
            case .Error:
                return "Error";
            case .Loading:
                return "Loading";
            case .Content:
                return "Content";
            }
        }
    }
    
    // MARK: - Outlets
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet weak var viewError: UIView!
    @IBOutlet weak var viewEmpty: UIView!
    @IBOutlet weak var viewLoading: UIView!
    
    @IBOutlet weak var labelError: UILabel!
    @IBOutlet weak var labelEmpty: UILabel!
    @IBOutlet weak var labelLoading: UILabel!
    
    // MARK: - Members
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl: UIRefreshControl = UIRefreshControl();
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh");
        refreshControl.addTarget(self, action: #selector(ListRepoModuleView.onPulledToRefresh(_:)), forControlEvents: UIControlEvents.ValueChanged);
        
        return refreshControl;
    }();
    
    var stateMachine: ViewStateMachine? = nil;
    var data: Array<Repo> = [];
    private var hakuba: Hakuba!;
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        self.synthesizeController();
        
        self.presenter?.loadRepos("RoRoche", pulledToRefresh: false);
    }
    
    override func viewWillAppear(animated: Bool) {
        hakuba.deselectAllCells(animated: true);
        super.viewWillAppear(animated);
    }
    
    // MARK: - Synthesize
    
    func synthesizeController() {
        self.tableView.addSubview(self.refreshControl);
        
        // StatefulViewController
        
        stateMachine = ViewStateMachine(view: tableView);
        // Add states
        stateMachine[ViewState.Loading.value] = viewLoading;
        stateMachine[ViewState.Error.value] = viewError;
        stateMachine[ViewState.Empty.value] = viewEmpty;
        stateMachine[ViewState.Content.value] = tableView;
        
        // configure Hakuba
        hakuba = Hakuba(tableView: tableView);
        hakuba.registerCellByNib(RepoCell);
        hakuba.cellEditable = false;
    }
    
    // MARK: - ListRepoModuleViewProtocol
    func showLoadingFromNetwork(pulledToRefresh: Bool) {
        self.labelLoading.text = "Loading data from network...";
        
        if(!pulledToRefresh) {
            stateMachine.transitionToState(.View(ViewState.Loading.value), animated: true);
        }
    }
    
    func showLoadingFromDatabase(pulledToRefresh: Bool) {
        self.labelLoading.text = "Loading data from database...";
        
        if(!pulledToRefresh) {
            stateMachine.transitionToState(.View(ViewState.Loading.value), animated: true);
        }
    }
    
    func showRepos(repos: Array<Repo>, pulledToRefresh: Bool) {
        self.data = repos;
        self.resetRepoCellModels(pulledToRefresh);
    }
    
    func showError(error: NSError) {
        Async.main {
            self.labelError.text = "An error occurred...";
            self.stateMachine.transitionToState(.View(ViewState.Error.value), animated: true);
        }
    }
    
    // MARK: - Selectors
    
    @IBAction func onClickRetry(sender: AnyObject) {
        self.presenter?.loadRepos("RoRoche", pulledToRefresh: false);
    }
    
    // MARK: - User interactions
    
    func onPulledToRefresh(sender: AnyObject) {
        self.presenter?.loadRepos("RoRoche", pulledToRefresh: true);
    }
    
    // MARK: - Table view specific job
    
    func presentDetailRepoModule(index: Int) {
        let repo = data[index]
        print(repo.name)
        print(data.count)
        self.presenter?.presentDetailRepoModuleModule(repo);
    }
    
    func resetRepoCellModels(pulledToRefresh: Bool) {
        var cellModels: Array<RepoCellModel> = Array<RepoCellModel>();
        
//        for repo: Repo in self.data {
//            let cellModel: RepoCellModel = RepoCellModel(avatarUrl: repo.avatarUrl!, name: repo.name!) { _ in
//                debugPrint("Did select cell with title = \(avatarUrl)")
//                debugPrint(name)
//                self.presenter?.presentDetailRepoModuleModule(repo);
//                self.tableView.deselectRowAtIndexPath(self.tableView.indexPathForSelectedRow!, animated: true);
//            };
//
//            cellModels.append(cellModel);
//        }
        
//        let topCellmodels = (0..<self.data.count).map { [weak self] i -> RepoCellModel in
//            let name = self!.data[i].name
//            let avatarUrl = self!.data[i].avatarUrl
//            
//            return RepoCellModel(avatarUrl: avatarUrl!, name: name!) { _ in
//                let repo = self!.data[i]
//                print("Did select new cell : \(i)")
//////                self?.pushChildViewController()
//                print(repo.name)
//                self!.presenter?.presentDetailRepoModuleModule(repo);
////                self!.presentDetailRepoModule(i)
//                self!.tableView.deselectRowAtIndexPath(self!.tableView.indexPathForSelectedRow!, animated: true);
//            }
//        }
//        cellModels = topCellmodels
        
        
        for repo: Repo in self.data {
            let cellModel: RepoCellModel = RepoCellModel(avatarUrl: repo.avatarUrl!, name: repo.name!) { _ in
                debugPrint(repo.name)
                self.presenter?.presentDetailRepoModuleModule(repo);
                self.tableView.deselectRowAtIndexPath(self.tableView.indexPathForSelectedRow!, animated: true);
            };
            
            cellModels.append(cellModel);
        }
        
        Async.main {
            if(self.hakuba.sectionsCount > 0) {
                self.hakuba[0].reset(cellModels)
                    .bump();
            } else {
                let section = Section();
                self.hakuba
                    .insert(section, atIndex: 1)
                    .bump();
                self.hakuba[0].append(cellModels)
                    .bump();
            }
        }
        
        if(self.data.count > 0) {
            self.stateMachine.transitionToState(.View(ViewState.Content.value), animated: true);
        } else {
            self.stateMachine.transitionToState(.View(ViewState.Empty.value), animated: true);
        }
        
        if(pulledToRefresh) {
            self.refreshControl.endRefreshing();
        }
        
    }
    
    // MARK: - StatefulViewController
    
    func hasContent() -> Bool {
        return (self.data.count > 0);
    }
    
    func handleErrorWhenContentAvailable(error: ErrorType) {
    }
}
