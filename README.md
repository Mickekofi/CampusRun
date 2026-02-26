# Campus Run – UEW Smart Transport System

The **Campus Run** is the smart campus transport system for the
**University of Education, Winneba (UEW)**.  
It provides students, staff and faculty with a digital platform to view
bus routes, check live schedules, book seats, and track buses across
all UEW campuses and surrounding towns.

---

## Features

| Feature | Description |
|---------|-------------|
| 🗺️ **Routes** | 8 routes covering all UEW campuses and Winneba town |
| 🕐 **Schedule** | Real-time departure/arrival timetable with filter by route |
| 🎫 **Booking** | Reserve seats online with instant confirmation & reference |
| 📍 **Bus Tracker** | Live occupancy and route progress for all active buses |
| 📱 **Responsive UI** | Works on desktop, tablet and mobile |

---

## Getting Started

No build step is required — the project is a static HTML/CSS/JS application.

1. Clone the repository:
   ```bash
   git clone https://github.com/Mickekofi/CampusRun.git
   cd CampusRun
   ```
2. Open `index.html` in your browser, **or** serve it with any static file server:
   ```bash
   # Python 3
   python -m http.server 8080
   # Then visit http://localhost:8080
   ```

---

## Project Structure

```
CampusRun/
├── index.html            # Main HTML page
├── public/
│   ├── css/
│   │   └── styles.css    # All styles
│   └── js/
│       ├── data.js       # Route, schedule, and bus data
│       └── app.js        # Application logic
└── README.md
```

---

## Campuses & Routes Covered

- **Main Campus** ↔ South Campus
- **Main Campus** ↔ Winneba Town
- **South Campus** ↔ Winneba Town
- **Main Campus** ↔ Kumasi Campus
- **Main Campus** ↔ Mampong Campus
- **Hostel Loop** (on-campus shuttle)
- **Main Campus** ↔ Apam
- **Main Campus** ↔ Accra

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
