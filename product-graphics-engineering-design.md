## Graphics Engineering: The 60:30:10 Rule

CampusRun applies the **60:30:10 Rule** as a product-graphics engineering standard.  
This is not only a visual style choice — it is a usability and performance decision for the UEW campus environment.

The ratio improves:
- visual hierarchy,
- faster scan/read speed for students in motion,
- brand consistency across **North, Central, and South** campuses.

### 📐 Composition Breakdown

#### 60% — Primary Base (Dominant)
**Colors:** `blackStart (#000000)`, `blackEnd (#171717)`  
**Used in:** app scaffolds, backgrounds, large surfaces.

**Engineering intent:**
- **Power efficiency:** true black helps reduce OLED battery usage.
- **Focus control:** dark surfaces push interactive objects (bike cards, station actions) forward.

#### 30% — Secondary Support (Complementary)
**Colors:** `greenMid (#00C278)`, `whiteMuted (#E5E5E5)`  
**Used in:** secondary buttons, icons, unselected tabs, body text.

**Engineering intent:**
- **Semantic trust:** green communicates availability and readiness.
- **Readable contrast:** muted white prevents eye strain common with pure white on black.

#### 10% — Accent (Emphasis)
**Color:** `redYellowMid (#FF7A21)`  
**Used in:** primary CTAs, progress bars, active selection borders.

**Engineering intent:**
- **Urgency and action:** the accent is reserved for high-priority actions (e.g., Book/Unlock ride).
- **Attention routing:** users quickly identify the next critical interaction.

---

### 🖋 Typography & Visual Weight

| Element | Color | Weight | Purpose |
| :-- | :-- | :-- | :-- |
| Headings | white | Bold (`w700`) | Immediate screen context recognition |
| Standard UI text | whiteMuted | Normal (`w400`) | Secondary instruction and supporting info |
| Interactive text | redYellowMid | Bold (`w700`) | Action-oriented prompts and status emphasis |

---

### 🌓 The “Vivid Dark” Aesthetic

CampusRun uses **deep-black high contrast** instead of standard charcoal dark mode.

**Why this matters:**
- **Anti-glare behavior:** accent elements remain visible under bright sunlight.
- **Premium smart-campus feel:** gradients avoid flat visuals while preserving clarity.

---

### 🛠 Component Example: `AppStatusChip`

`AppStatusChip` demonstrates the rule in one component:
- **60% surface:** dark chip body,
- **30% information:** readable text label,
- **10% signal:** dynamic status indicator color (e.g., green = ready, orange = in-transit).