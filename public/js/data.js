/**
 * Campus Run – UEW Smart Transport System
 * Static data: routes, schedules, and buses
 */

const ROUTES = [
  {
    id: "R01",
    name: "Main Campus – South Campus",
    from: "Main Campus",
    to: "South Campus",
    stops: ["Main Gate", "Admin Block", "Library Junction", "South Campus Gate"],
    distance: "4 km",
    duration: "15 min",
    fare: "GH₵ 1.50",
  },
  {
    id: "R02",
    name: "Main Campus – Winneba Town",
    from: "Main Campus",
    to: "Winneba Town",
    stops: ["Main Gate", "Commercial Area", "Winneba Lorry Park"],
    distance: "6 km",
    duration: "20 min",
    fare: "GH₵ 2.00",
  },
  {
    id: "R03",
    name: "South Campus – Winneba Town",
    from: "South Campus",
    to: "Winneba Town",
    stops: ["South Campus Gate", "Commercial Area", "Winneba Central Market"],
    distance: "5 km",
    duration: "18 min",
    fare: "GH₵ 1.50",
  },
  {
    id: "R04",
    name: "Main Campus – Kumasi Campus",
    from: "Main Campus",
    to: "Kumasi Campus",
    stops: ["Main Gate", "Highway Junction", "Kumasi Campus"],
    distance: "220 km",
    duration: "3 hrs 30 min",
    fare: "GH₵ 45.00",
  },
  {
    id: "R05",
    name: "Main Campus – Mampong Campus",
    from: "Main Campus",
    to: "Mampong Campus",
    stops: ["Main Gate", "Nsawam Junction", "Koforidua", "Mampong Campus"],
    distance: "180 km",
    duration: "3 hrs",
    fare: "GH₵ 40.00",
  },
  {
    id: "R06",
    name: "Hostel Loop",
    from: "Valco Hall",
    to: "Valco Hall",
    stops: ["Valco Hall", "International Hall", "Presbyterian Hall", "Faculty of Education", "Valco Hall"],
    distance: "3 km",
    duration: "12 min",
    fare: "Free",
  },
  {
    id: "R07",
    name: "Main Campus – Apam",
    from: "Main Campus",
    to: "Apam",
    stops: ["Main Gate", "Winneba Town", "Apam Junction", "Apam"],
    distance: "35 km",
    duration: "50 min",
    fare: "GH₵ 8.00",
  },
  {
    id: "R08",
    name: "Main Campus – Accra",
    from: "Main Campus",
    to: "Accra (37 Military Hospital)",
    stops: ["Main Gate", "Kasoa", "Circle", "37 Military Hospital"],
    distance: "65 km",
    duration: "1 hr 30 min",
    fare: "GH₵ 15.00",
  },
];

const SCHEDULE_TEMPLATES = [
  { routeId: "R01", departures: ["06:00", "07:00", "08:00", "12:00", "13:00", "14:00", "17:00", "18:00"] },
  { routeId: "R02", departures: ["06:30", "09:00", "12:30", "15:00", "18:30"] },
  { routeId: "R03", departures: ["07:00", "09:30", "12:00", "15:30", "18:00"] },
  { routeId: "R04", departures: ["05:00", "13:00"] },
  { routeId: "R05", departures: ["05:30", "14:00"] },
  { routeId: "R06", departures: ["07:00", "07:30", "08:00", "12:00", "13:00", "17:00", "18:00", "19:00"] },
  { routeId: "R07", departures: ["06:00", "10:00", "14:00", "17:30"] },
  { routeId: "R08", departures: ["05:00", "06:00", "14:00", "16:00"] },
];

const BUSES = [
  { id: "UEW-001", plate: "GR-1234-21", route: "R01", driver: "Kwame Asante",  capacity: 30, occupied: 18, progress: 45, status: "on-time" },
  { id: "UEW-002", plate: "GR-5678-21", route: "R02", driver: "Ama Serwaa",    capacity: 30, occupied: 22, progress: 70, status: "on-time" },
  { id: "UEW-003", plate: "GR-9012-22", route: "R03", driver: "Kofi Boateng",  capacity: 25, occupied: 10, progress: 20, status: "delayed" },
  { id: "UEW-004", plate: "GR-3456-22", route: "R06", driver: "Abena Mensah",  capacity: 20, occupied: 20, progress: 90, status: "on-time" },
  { id: "UEW-005", plate: "GR-7890-23", route: "R08", driver: "Yaw Darko",     capacity: 40, occupied: 35, progress: 55, status: "on-time" },
  { id: "UEW-006", plate: "GR-2345-23", route: "R07", driver: "Akosua Frimpong", capacity: 25, occupied: 8, progress: 30, status: "on-time" },
];
