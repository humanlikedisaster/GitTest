# GitTest

Git test is a simple repository viewer for iOS. You can enter user/organization name and get list of all repositories linked to this user/organization.

# Goals

My task was to create repository viewer for GitHub. All repositories must be sorted in sections by language there they need to be sorted by star count.

# Limits

List of third part libraries was limited to any OAuth library, GraphQL to communicate with v4 GitHub api, RxSwift and Realm data.

# Architecture

I've used simple MVVM architecture pattern, there role of ViewModel perform Coordinator class. NetworkService and Database classes are model classes. ViewController acting as View linked with RxSwift to Coordinator repos Variable. 

# Network 

For getting data from GitHub I've used v3 api with /orgs/:org/repos or /users/:user/repos endpoints. Because of limits (100 repos per page) I've used recursive function to get all data. Firsly app trying to find organization with searched name, if there is no such organization - it tries to get repos by username. All repos after is stored to Realm database, and after the end of request queue Database is used to show all information. If is request fail or timeout - app try to use stored in local database information.
