# Can not find Module(For flutter files)
- this can mostly happen when you just change a file name;

- Fix: Although the other files linked to the changed file automatically updates(because of extentions) to the new file, You have to visit all of them and save each file before you start it.

# Can not find Module(Identifing the file with the problem)(for node.js files )
`michael-ubuntu@ubuntu:~/CampusRun/backend$ node server.js
node:internal/modules/cjs/loader:1210
  throw err;
  ^

Error: Cannot find module '../controllers/Administrator/signupController'
Require stack:
- /home/michael-ubuntu/CampusRun/backend/routes/Users/signupRoutes.js
- /home/michael-ubuntu/CampusRun/backend/server.js
    at Module._resolveFilename (node:internal/modules/cjs/loader:1207:15)
    at Module._load (node:internal/modules/cjs/loader:1038:27)
    at Module.require (node:internal/modules/cjs/loader:1289:19)
    at require (node:internal/modules/helpers:182:18)
    at Object.<anonymous> (/home/michael-ubuntu/CampusRun/backend/routes/Users/signupRoutes.js:2:20)
    at Module._compile (node:internal/modules/cjs/loader:1521:14)
    at Module._extensions..js (node:internal/modules/cjs/loader:1623:10)
    at Module.load (node:internal/modules/cjs/loader:1266:32)
    at Module._load (node:internal/modules/cjs/loader:1091:12)
    at Module.require (node:internal/modules/cjs/loader:1289:19) {
  code: 'MODULE_NOT_FOUND',
  requireStack: [
    '/home/michael-ubuntu/CampusRun/backend/routes/Users/signupRoutes.js',
    '/home/michael-ubuntu/CampusRun/backend/server.js'
  ]
}
`

- To Identify;
* The error is indicated by the word "error:"
* The file in trouble is the first file just below or after the word "Require stack:"


# Installing a dependancy Use
`flutter pub add dependancy_name`

then apply:
  `flutter clean`
  `flutter pub get`