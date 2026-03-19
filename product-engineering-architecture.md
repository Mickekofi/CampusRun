# Single Source of Truth

- It serves as the single source of truth for all frontend-to-backend communication, routing, and data persistence.

1. Frontend say `frontend/lib/Users/signupscreen.dart` sends a POST request

```dart
final response = await http.post(
  Uri.parse("http://192.168.1.5:5000/api/signup"),
  headers: {"Content-Type": "application/json"},
  body: jsonEncode({
    "name": name,
    "email": email,
    "password": password,    
  }),
);

final data = jsonDecode(response.body);
```

directly pointing to The Right Address:  
The right address is made up off two parts:

1. Server's own address IP address (with a port included),eg: `http://192.168.1.100:5000`

In addition to(+)

2. the resource address(creating endpoint address(look at step 5 for reference)) which is directly assigned to One Specified route address

In total(1+2) you get; eg: `http://192.168.1.100:5000/api/signuproutes`

---

2) If Address and Resource exits, example;

```js
// a). Importing and assigning the available routes resources living in the routes folder.
//=================================================================
const signupRoutes = require('./routes/Users/signupRoutes');
```

and

```js
// b). We then create address(endpoints) for each of the imported resources(routes),
app.use('/api/signuproutes', signupRoutes);
```

It routes to the `backend/Users/routes` directory say a file called `backend/Users/routes/signupRoutes.js`

---

3. `backend/Users/routes/signupRoutes.js` (A file Responsible for routing) also Sends out the response the `backend/Users/controllers` lets say a file called `backend/controller/signupController.js`

---

3. `backend/Users/controller/signupController.js`  
( A file responsible for validations,database logics, business strategy logics at the backend side) also sends it reponse to the database in the `backend/config` say a file called `db.js`, and Back to the Frontend.

---

# The Folder Structure
