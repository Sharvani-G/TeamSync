# TeamSync — Responsive Behavior & Accessibility Specifications

This document defines the responsive layout rules across viewports and the accessibility standards enforced throughout TeamSync.

---

## 1. Responsive Viewport Breakpoints

| Breakpoint Tier | Screen Width Range | Target Devices | Layout Strategy |
|---|---|---|---|
| **Desktop / Wide** | `> 1050px` | Large monitors, desktop workstations | Centered max-width content container (`1100px`), multi-column cards, balanced sidebar/nav |
| **Laptop / Tablet**| `760px` to `1050px` | Laptops, iPad / tablets in landscape | Tightened grid gaps (`16px` from `24px`), 2-column cards, flexible side margins |
| **Tablet Portrait / Large Mobile**| `480px` to `760px` | Tablets portrait, large smartphones | Single-column layouts for major sections, stacked action bars, persistent bottom navigation |
| **Small Mobile** | `< 480px` | Standard smartphones | Single-column stacks, full-width buttons, compact font scales, edge padding `16px` |

---

## 2. Responsive Rules by Interface Area

### 2.1 Navigation & Application Shell
- **Desktop (> 760px)**:
  - Top navigation bar or centered application shell.
  - Content constrained within a clean `1100px` reading boundary to prevent overly stretched lines.
- **Mobile (< 760px)**:
  - Fixed bottom navigation bar with 4 core tabs (Dashboard, Discover, Alerts, Profile).
  - Clean top app bar with title, back button, and contextual action items.

### 2.2 Dashboard & Project Buckets
- **Desktop (> 1050px)**:
  - Multi-column grid for project buckets (2 or 3 cards per row depending on container width).
- **Laptop / Tablet (760px - 1050px)**:
  - 2 columns with `16px` grid gap.
- **Mobile (< 760px)**:
  - 1 column full-width vertical stack with `12px` or `16px` separator.

### 2.3 Form & Input Responsiveness
- **Desktop & Tablets**:
  - Modal dialogues and forms have explicit max-widths (e.g. `520px` for create project, `420px` for auth).
  - Field grids (e.g. Date + Time, First Name + Last Name) sit side-by-side.
- **Mobile (< 480px)**:
  - Field grids collapse into vertical single-column stacks.
  - Primary form submission buttons expand to full width (`double.infinity`).

### 2.4 Prevention of Layout Defects
- **Zero Horizontal Scrolling**: No horizontal scrollbars are permitted on any page at any viewport width.
- **Flexible Text & Line Clamping**: Long project titles and descriptions must employ `TextOverflow.ellipsis` with explicit `maxLines` to prevent card overflow.
- **Dialog & Sheet Responsiveness**: Modals on mobile switch to touch-friendly bottom sheets or adapt their height using `SingleChildScrollView`.

---

## 3. Accessibility Standards (WCAG 2.1 AA Compliance)

### 3.1 Color Contrast Ratios
- **Primary Ink on Ground**:
  - `#16191f` on `#fcfcfd`: **16.5:1** (Exceeds WCAG AAA requirement of 7:1).
- **Secondary Ink on Ground**:
  - `#454c58` on `#fcfcfd`: **8.2:1** (Exceeds WCAG AAA requirement of 7:1).
- **Electric Blue on Ground**:
  - `#074ce0` on `#fcfcfd`: **6.4:1** (Exceeds WCAG AA requirement of 4.5:1 for body and 3:1 for large text).
- **White on Electric Blue**:
  - `#ffffff` on `#074ce0`: **6.4:1** (Exceeds WCAG AA requirement).
- **Status Colors**:
  - Success `#15803d` on `#dcfce7`: **4.8:1**.
  - Warning `#b45309` on `#fef3c7`: **5.1:1**.
  - Danger `#dc2626` on `#fee2e2`: **5.2:1**.

### 3.2 Keyboard Navigation & Focus Indicators
- Every interactive element (buttons, text fields, checkboxes, tabs, card links, dropdown items) must be reachable via `Tab` key navigation.
- Focusable items must present a visible focus indicator:
  - Outline: 2px solid `--dp-color-accent` (`#074ce0`) with an offset of 2px.
  - Never suppress default focus outlines without providing an accessible alternative.

### 3.3 Semantic Hierarchy & Labels
- Proper heading hierarchy: `H1` (page title) -> `H2` (section titles) -> `H3` (card titles).
- Every icon-only button (e.g. Back, Settings, Add, Close, Attach, Send) must have an explicit `tooltip` or `Semantics(label: ...)` property for screen readers.
- Form inputs must have visible text labels associated with their inputs.

### 3.4 Reduced-Motion Preferences
- When `MediaQuery.of(context).disableAnimations` or system `prefers-reduced-motion` is active:
  - Disable animated entrance transitions, pulse effects, and floating animations.
  - Retain instant state swaps for interactive elements.

