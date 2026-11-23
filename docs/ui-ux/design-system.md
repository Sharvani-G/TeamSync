# TeamSync — Authoritative Visual Design System

## 1. Visual Identity Overview

TeamSync is a modern, high-performance, collaborative project management platform built for agile and academic teams.
The visual identity embraces a **predominantly light, open, sophisticated SaaS interface** characterized by:
- A clean, near-white canvas (`--dp-color-ground: #fcfcfd`) providing maximum legibility and visual calm.
- Crisp, high-contrast dark typography (`--dp-color-ink: #16191f`) delivering executive-level clarity and visual confidence.
- Electric-blue action accents (`--dp-color-accent: #074ce0`) applied with restraint for primary call-to-actions, active navigation markers, and interactive focus states.
- Clean white card surfaces (`--dp-color-panel: #ffffff`) with subtle 1px hairline borders (`--dp-color-rule: #dde0e6`) and a precise 12px panel radius (`--dp-radius-panel: 12px`).
- Carefully controlled dark section surfaces (`--dp-color-field: #16191f`) reserved for contextual emphasis (e.g., active call monitors, code blocks, terminal logs, or primary keyframes).
- Consistent spacing, balanced information density, and zero superficial clutter.

---

## 2. Mandatory Design Tokens

All TeamSync UI components, screens, theme definitions, and styling declarations MUST derive directly from the authoritative tokens below. No arbitrary hardcoded colors or ad-hoc measurements are permitted.

### 2.1 Color Tokens

| Token | CSS Variable | Hex Value | Flutter Color | Role & Intended Application |
|---|---|---|---|---|
| Ground | `--dp-color-ground` | `#fcfcfd` | `const Color(0xFFFCFCFD)` | Main application scaffold & window background |
| Ink (Primary) | `--dp-color-ink` | `#16191f` | `const Color(0xFF16191F)` | Primary text, titles, headings, active icons |
| Ink Secondary | `--dp-color-ink-secondary`| `#454c58` | `const Color(0xFF454C58)` | Supporting descriptions, metadata, subtitles, muted icons |
| Ground Muted | `--dp-color-ground-muted` | `#f3f4f6` | `const Color(0xFFF3F4F6)` | Pale-grey section fills, pill backgrounds, chips |
| Rule / Border | `--dp-color-rule` | `#dde0e6` | `const Color(0xFFDDE0E6)` | Dividers, container borders, input field outlines |
| Accent (Electric Blue)| `--dp-color-accent` | `#074ce0` | `const Color(0xFF074CE0)` | Primary interactive buttons, active tab indicators, key toggles |
| On Accent | `--dp-color-on-accent` | `#ffffff` | `const Color(0xFFFFFFFF)` | Text and icons placed on `--dp-color-accent` |
| Field (Dark Surface)| `--dp-color-field` | `#16191f` | `const Color(0xFF16191F)` | Selective dark hero panels, call stages, terminal blocks |
| On Field | `--dp-color-on-field` | `#fcfcfd` | `const Color(0xFFFCFCFD)` | Primary headings and text placed on dark field surfaces |
| On Field Secondary | `--dp-color-on-field-secondary`| `#d0d4dd` | `const Color(0xFFD0D4DD)` | Supporting text and secondary labels on dark field surfaces |
| Panel / Surface | `--dp-color-panel` | `#ffffff` | `const Color(0xFFFFFFFF)` | White card surfaces, dialog backgrounds, dropdown panels |

### 2.2 Semantic & Status Tokens

Status colors are strictly restrained to maintain visual cohesion with the authoritative palette:

| Token | Hex Value | Flutter Color | Background Fill | Intended Usage |
|---|---|---|---|---|
| Success | `#15803d` | `const Color(0xFF15803D)` | `#dcfce7` (10% tint) | Completed tasks, active calls, accepted requests |
| Warning | `#b45309` | `const Color(0xFFB45309)` | `#fef3c7` (10% tint) | Pending join requests, upcoming meetings, warnings |
| Danger / Error | `#dc2626` | `const Color(0xFFDC2626)` | `#fee2e2` (10% tint) | Destructive actions, validation errors, reject actions |
| Info / Progress | `#074ce0` | `const Color(0xFF074CE0)` | `#eff6ff` (10% tint) | Informational badges, progress meters, blue alerts |

---

## 3. Typography System

The typography architecture uses a strict two-family system loaded via Google Fonts:
1. **Display & Heading Typography**: **Host Grotesk**
   -confidently tracked, geometric, modern grotesque styling for page titles, section headers, key figures, and prominent callouts.
   - Font weights: Medium (`500`), SemiBold (`600`), Bold (`700`), ExtraBold (`800`).
2. **Interface & Body Typography**: **Instrument Sans**
   - High-legibility humanist sans-serif optimized for continuous reading, form inputs, navigation items, buttons, microcopy, and metadata.
   - Font weights: Regular (`400`), Medium (`500`), SemiBold (`600`).

### 3.1 Type Scale Hierarchy

| Token | Font Family | Size | Weight | Line Height | Tracking | Application |
|---|---|---|---|---|---|---|
| `display-1` | Host Grotesk | 36px | 800 (Bold) | 1.15 | -0.02em | Hero titles, entry landing headlines |
| `display-2` | Host Grotesk | 28px | 700 (Bold) | 1.20 | -0.015em | Top-level dashboard & view headings |
| `heading-1` | Host Grotesk | 22px | 700 (Bold) | 1.25 | -0.01em | Major section headers, modal titles |
| `heading-2` | Host Grotesk | 18px | 600 (SemiBold)| 1.30 | -0.005em | Card headers, list section headers |
| `heading-3` | Host Grotesk | 16px | 600 (SemiBold)| 1.35 | 0.00em | Compact card headers, table column groups |
| `body-large` | Instrument Sans | 16px | 400/500 | 1.60 | 0.00em | Primary narrative, readouts, intro copy |
| `interface` | Instrument Sans | 15px | 500 (Medium) | 1.40 | 0.00em | Standard interactive labels, menu items |
| `small` | Instrument Sans | 14px | 400/500 | 1.45 | 0.00em | Secondary descriptions, form input values |
| `metadata` | Instrument Sans | 13px | 400/500 | 1.40 | 0.01em | Timestamps, author names, status tags |
| `label` | Instrument Sans | 12px | 600 (SemiBold)| 1.30 | 0.03em | Uppercase section kickers, counter pills |

---

## 4. Spacing, Sizing, and Layout Tokens

| Token | Value | Flutter Equivalent | Description |
|---|---|---|---|
| `--dp-spacing-xxs` | 4px | `4.0` | Micro spacing, icon-label offsets |
| `--dp-spacing-xs` | 8px | `8.0` | Compact gaps, tag padding |
| `--dp-spacing-sm` | 12px | `12.0` | Form field inner vertical padding |
| `--dp-spacing-md` | 16px | `16.0` | Standard card padding, list item gaps |
| `--dp-spacing-lg` | 24px | `24.0` | Grid gaps, inter-section spacing |
| `--dp-spacing-xl` | 32px | `32.0` | Screen margins, major section separations |
| `--dp-spacing-xxl` | 48px | `48.0` | Hero container padding |
| `--dp-radius-sm` | 6px | `6.0` | Badges, small pills, menu items |
| `--dp-radius-md` | 8px | `8.0` | Input fields, standard buttons |
| `--dp-radius-panel` | 12px | `12.0` | Standard cards, modal dialogs, sheets |
| `--dp-radius-lg` | 16px | `16.0` | Elevated dashboard containers |
| `--dp-radius-full` | 9999px | `999.0` | Circular avatars, rounded pill buttons |
| `--dp-border-hairline`| 1px | `1.0` | All hairline container borders |

---

## 5. Surfaces, Elevation, and Borders

1. **Card Surfaces**:
   - Surface color: `--dp-color-panel` (`#ffffff`).
   - Border: 1px solid `--dp-color-rule` (`#dde0e6`).
   - Corner Radius: 12px (`--dp-radius-panel`).
   - Shadow: `BoxShadow(color: Color(0x0A16191F), blurRadius: 8, offset: Offset(0, 2))`.
2. **Elevated Surfaces (Modals / Popovers)**:
   - Surface color: `--dp-color-panel` (`#ffffff`).
   - Border: 1px solid `--dp-color-rule` (`#dde0e6`).
   - Shadow: `BoxShadow(color: Color(0x1416191F), blurRadius: 24, offset: Offset(0, 8))`.
3. **Muted Pale Sections**:
   - Surface color: `--dp-color-ground-muted` (`#f3f4f6`).
   - Border: 1px solid `--dp-color-rule` (`#dde0e6`).
   - Corner Radius: 12px (`--dp-radius-panel`).
4. **Dark Feature Surfaces**:
   - Surface color: `--dp-color-field` (`#16191f`).
   - Corner Radius: 12px (`--dp-radius-panel`).
   - Text on surface: `--dp-color-on-field` (`#fcfcfd`).

---

## 6. Motion and Interaction Timing

- **Interaction Duration**: `160ms` (`--dp-motion-interaction`).
- **Timing Function**: `ease-out` (`Curves.easeOut`).
- **Hover Lift**: Subtle `-1.5px` vertical translation with slight shadow expansion.
- **Active / Pressed**: Immediate return to neutral position with 0.98 scale or background tinting.
- **Reduced Motion**: Disables transitions and scale animations when user prefers reduced motion.

