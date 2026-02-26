/**
 * Campus Run – UEW Smart Transport System
 * Main application script
 */

/* ---- Utility helpers ---- */

/**
 * Returns a string like "HH:MM" offset by `minutes` from a "HH:MM" input.
 * @param {string} time - Base time in "HH:MM" format
 * @param {number} minutes - Minutes to add
 * @returns {string}
 */
function addMinutes(time, minutes) {
  const [h, m] = time.split(":").map(Number);
  const total = h * 60 + m + minutes;
  const hh = Math.floor(total / 60) % 24;
  const mm = total % 60;
  return `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
}

/**
 * Generates a random booking reference.
 * @returns {string}
 */
function genRef() {
  return "CR-" + new Date().getFullYear() + "-" + Math.floor(1000 + Math.random() * 9000);
}

/**
 * Parses route duration string to minutes.
 * @param {string} dur - e.g. "15 min" or "1 hr 30 min"
 * @returns {number}
 */
function durationToMinutes(dur) {
  let mins = 0;
  const hrMatch = dur.match(/(\d+)\s*hr/);
  const minMatch = dur.match(/(\d+)\s*min/);
  if (hrMatch) mins += parseInt(hrMatch[1], 10) * 60;
  if (minMatch) mins += parseInt(minMatch[1], 10);
  return mins;
}

/* ---- Build schedule rows ---- */
function buildSchedule() {
  const rows = [];
  const statuses = ["on-time", "on-time", "on-time", "delayed", "departed"];
  SCHEDULE_TEMPLATES.forEach((tmpl) => {
    const route = ROUTES.find((r) => r.id === tmpl.routeId);
    if (!route) return;
    const durMins = durationToMinutes(route.duration);
    const bus = BUSES.find((b) => b.route === tmpl.routeId);
    tmpl.departures.forEach((dep, i) => {
      const arrival = addMinutes(dep, durMins);
      const status = statuses[i % statuses.length];
      rows.push({
        routeId: route.id,
        routeName: route.name,
        from: route.from,
        to: route.to,
        departure: dep,
        arrival,
        plate: bus ? bus.plate : "TBA",
        status,
      });
    });
  });
  rows.sort((a, b) => a.departure.localeCompare(b.departure));
  return rows;
}

const SCHEDULE = buildSchedule();

/* ---- Render helpers ---- */

function statusBadge(status) {
  const map = {
    "on-time":  ["on-time",   "On Time"],
    delayed:    ["delayed",   "Delayed"],
    cancelled:  ["cancelled", "Cancelled"],
    departed:   ["departed",  "Departed"],
  };
  const [cls, label] = map[status] || ["on-time", status];
  return `<span class="status-badge status-badge--${cls}">${label}</span>`;
}

/* ---- Render routes ---- */
function renderRoutes() {
  const grid = document.getElementById("routes-grid");
  grid.innerHTML = ROUTES.map((r) => `
    <div class="route-card">
      <div class="route-card__header">
        <span class="route-badge">${r.id}</span>
      </div>
      <div class="route-card__title">${r.name}</div>
      <div class="route-card__path">
        ${r.stops.join(" → ")}
      </div>
      <div class="route-card__meta">
        <span>🛣️ ${r.distance}</span>
        <span>⏱️ ${r.duration}</span>
      </div>
      <div class="route-fare">${r.fare}</div>
    </div>
  `).join("");
}

/* ---- Render schedule ---- */
function renderSchedule(filterRouteId = "all") {
  const tbody = document.getElementById("schedule-body");
  const rows = filterRouteId === "all"
    ? SCHEDULE
    : SCHEDULE.filter((s) => s.routeId === filterRouteId);

  tbody.innerHTML = rows.map((s) => `
    <tr>
      <td><strong>${s.routeId}</strong></td>
      <td>${s.from}</td>
      <td>${s.to}</td>
      <td>${s.departure}</td>
      <td>${s.arrival}</td>
      <td>${s.plate}</td>
      <td>${statusBadge(s.status)}</td>
    </tr>
  `).join("");
}

/* ---- Populate dropdowns ---- */
function populateDropdowns() {
  const scheduleSelect = document.getElementById("schedule-route");
  const bookRouteSelect = document.getElementById("book-route");
  const trackRouteSelect = document.getElementById("track-route-select");

  ROUTES.forEach((r) => {
    const opt = (val, label) => {
      const el = document.createElement("option");
      el.value = val;
      el.textContent = label;
      return el;
    };
    scheduleSelect.appendChild(opt(r.id, `${r.id} – ${r.name}`));
    bookRouteSelect.appendChild(opt(r.id, `${r.id} – ${r.name}`));
    trackRouteSelect.appendChild(opt(r.id, `${r.id} – ${r.name}`));
  });
}

/* ---- Populate departure times based on selected route ---- */
function populateDepartureTimes(routeId) {
  const select = document.getElementById("book-time");
  select.innerHTML = '<option value="">-- Select departure time --</option>';
  const tmpl = SCHEDULE_TEMPLATES.find((t) => t.routeId === routeId);
  if (tmpl) {
    tmpl.departures.forEach((dep) => {
      const opt = document.createElement("option");
      opt.value = dep;
      opt.textContent = dep;
      select.appendChild(opt);
    });
  }
}

/* ---- Render buses ---- */
function renderBuses(buses) {
  const grid = document.getElementById("buses-grid");
  if (!buses || buses.length === 0) {
    grid.innerHTML = "<p style='color:var(--clr-muted)'>No buses found for the selected criteria.</p>";
    return;
  }
  grid.innerHTML = buses.map((b) => {
    const route = ROUTES.find((r) => r.id === b.route);
    const occupancyPct = Math.round((b.occupied / b.capacity) * 100);
    return `
      <div class="bus-card">
        <div class="bus-card__header">
          <span class="bus-icon">🚌</span>
          <div>
            <div class="bus-card__number">${b.id}</div>
            <div style="font-size:.75rem;color:var(--clr-muted)">${b.plate}</div>
          </div>
          ${statusBadge(b.status)}
        </div>
        <div class="bus-card__route">${route ? route.name : b.route}</div>
        <div class="progress-bar" title="Route progress: ${b.progress}%">
          <div class="progress-bar__fill" style="width:${b.progress}%"></div>
        </div>
        <div class="bus-card__info">
          <span>👤 Driver: ${b.driver}</span>
          <span>🪑 Seats: ${b.occupied}/${b.capacity} (${occupancyPct}%)</span>
          <span>📍 Progress: ${b.progress}%</span>
        </div>
      </div>
    `;
  }).join("");
}

/* ---- Booking form ---- */
function initBookingForm() {
  const form = document.getElementById("booking-form");
  const confirmation = document.getElementById("booking-confirmation");
  const newBookingBtn = document.getElementById("new-booking-btn");

  // Set minimum date to today
  const today = new Date().toISOString().split("T")[0];
  document.getElementById("book-date").min = today;
  document.getElementById("book-date").value = today;

  document.getElementById("book-route").addEventListener("change", (e) => {
    populateDepartureTimes(e.target.value);
  });

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const name   = document.getElementById("passenger-name").value.trim();
    const pid    = document.getElementById("passenger-id").value.trim();
    const phone  = document.getElementById("passenger-phone").value.trim();
    const route  = document.getElementById("book-route").value;
    const date   = document.getElementById("book-date").value;
    const time   = document.getElementById("book-time").value;
    const seats  = document.getElementById("book-seats").value;

    // Basic validation
    let valid = true;
    [
      ["passenger-name", name],
      ["passenger-id", pid],
      ["passenger-phone", phone],
      ["book-route", route],
      ["book-date", date],
      ["book-time", time],
    ].forEach(([id, val]) => {
      const el = document.getElementById(id);
      if (!val) {
        el.classList.add("error");
        valid = false;
      } else {
        el.classList.remove("error");
      }
    });

    if (!valid) return;

    const routeObj = ROUTES.find((r) => r.id === route);
    const ref = genRef();

    document.getElementById("confirmation-details").textContent =
      `${name}, your seat${seats > 1 ? "s" : ""} (×${seats}) on route ` +
      `${routeObj ? routeObj.name : route} departing at ${time} on ${date} ` +
      `have been reserved successfully.`;
    document.getElementById("confirmation-ref").textContent = ref;

    form.classList.add("hidden");
    confirmation.classList.remove("hidden");
  });

  newBookingBtn.addEventListener("click", () => {
    form.reset();
    document.getElementById("book-date").value = today;
    document.getElementById("book-time").innerHTML = '<option value="">-- Select departure time --</option>';
    confirmation.classList.add("hidden");
    form.classList.remove("hidden");
  });
}

/* ---- Bus tracker ---- */
function initTracker() {
  const trackBtn = document.getElementById("track-btn");
  trackBtn.addEventListener("click", () => {
    const routeId = document.getElementById("track-route-select").value;
    if (routeId) {
      renderBuses(BUSES.filter((b) => b.route === routeId));
    } else {
      renderBuses(BUSES);
    }
  });
  // Show all buses by default
  renderBuses(BUSES);
}

/* ---- Schedule filter ---- */
function initScheduleFilter() {
  document.getElementById("schedule-route").addEventListener("change", (e) => {
    renderSchedule(e.target.value);
  });
}

/* ---- Navbar active state & mobile toggle ---- */
function initNav() {
  const hamburger = document.getElementById("hamburger");
  const navLinks = document.getElementById("nav-links");

  hamburger.addEventListener("click", () => {
    navLinks.classList.toggle("open");
  });

  // Close menu when a link is clicked
  navLinks.querySelectorAll(".nav-link").forEach((link) => {
    link.addEventListener("click", () => {
      navLinks.classList.remove("open");
    });
  });

  // Highlight active section on scroll
  const sections = document.querySelectorAll("section[id]");
  const links = document.querySelectorAll(".nav-link[data-section]");

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          links.forEach((l) => {
            l.classList.toggle("active", l.dataset.section === entry.target.id);
          });
        }
      });
    },
    { threshold: 0.4 }
  );

  sections.forEach((s) => observer.observe(s));
}

/* ---- Footer year ---- */
function initFooter() {
  document.getElementById("footer-year").textContent = new Date().getFullYear();
}

/* ---- Init ---- */
document.addEventListener("DOMContentLoaded", () => {
  renderRoutes();
  populateDropdowns();
  renderSchedule();
  initBookingForm();
  initTracker();
  initScheduleFilter();
  initNav();
  initFooter();
});
