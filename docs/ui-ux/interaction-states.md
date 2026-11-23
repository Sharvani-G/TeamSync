# TeamSync — Interaction and State Specification

This document provides a comprehensive state matrix for interactive components, navigation elements, inputs, forms, and feedback mechanisms across TeamSync.

---

## 1. Global Interaction State Matrix

| State | Visual Treatment | Cursor | Accessibility & Feedback |
|---|---|---|---|
| **Normal (Resting)** | Standard token-defined background, border, text color | Default / Pointer | Standard DOM element state |
| **Hover** | Subtle color shift (darkened for buttons, tinted for cards), `-1.5px` vertical lift for elevated items | Pointer | Tooltips on icon-only actions |
| **Focus (Keyboard)** | Visible 2px focus ring (`--dp-color-accent: #074ce0` with 30% alpha offset), high contrast | Pointer / Text | Focus trapped in modals, tab-indexed order |
| **Active / Pressed** | Returns to resting position (lift removed), 0.98 scale or 10% dark overlay | Pointer | Instant tactile response |
| **Selected** | Primary blue background or high-contrast border and bold typography | Pointer | `aria-selected="true"`, selected icon |
| **Disabled** | Muted background (`#e5e7eb`), muted text (`#9ca3af`), no border highlights | Not-allowed | `aria-disabled="true"`, non-focusable |
| **Loading** | Action label hidden, spinner rendered with fixed dimensions | Wait / Progress | `aria-busy="true"`, disable duplicate triggers |
| **Success** | Green accent (`#15803d`) on ground tint (`#dcfce7`), checkmark icon | Default | Toast or inline notification |
| **Warning** | Amber accent (`#b45309`) on ground tint (`#fef3c7`), warning icon | Default | Caution banner / chip |
| **Error / Failed** | Red accent (`#dc2626`) on ground tint (`#fee2e2`), error icon | Default | `aria-invalid="true"`, assistive error string |
| **Empty** | Centered muted container with descriptive guidance | Default | Clear empty state description, action prompt |

---

## 2. Detailed Component State Behaviors

### 2.1 Buttons (`ElevatedButton`, `OutlinedButton`, `TextButton`)
- **Normal**:
  - Primary: Background `#074ce0`, text `#ffffff`.
  - Secondary: Background `#ffffff`, border `1px solid #dde0e6`, text `#16191f`.
- **Hover (Desktop / Mouse)**:
  - Transition duration: `160ms` (`Curves.easeOut`).
  - Primary: Background shifts to `#063ec0`.
  - Secondary: Background shifts to `#f3f4f6`, border shifts to `#cfd4dc`.
- **Pressed**:
  - Slight scale transformation `0.98`.
- **Loading State**:
  - Replaces text with a `SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))`.
  - Prevents multiple taps while an async operation is in-flight.

### 2.2 Text Inputs & Textareas
- **Normal**: Background `#ffffff`, border `1px solid #dde0e6`, text `#16191f`.
- **Hover**: Border darkens slightly to `#cfd4dc`.
- **Focus**: Border highlights to `1.5px solid #074ce0`, subtle ambient focus glow.
- **Error State**:
  - Border changes to `1px solid #dc2626`.
  - Helper/error text rendered below in `#dc2626` with `12px` font size.
  - Suffix icon displays an error indicator where applicable.
- **Disabled State**:
  - Background `#f3f4f6`, text `#9ca3af`, border `#e5e7eb`.

### 2.3 List Tiles & Interactive Cards
- **Normal**: White surface (`#ffffff`), `1px solid #dde0e6`, standard text colors.
- **Hover**: Background shifts to `#fcfcfd`, border shifts to `#074ce0` with subtle elevation.
- **Pressed**: Ripple effect with electric blue tint (`#074ce0.withOpacity(0.08)`).
- **Selected**: Highlighted with soft blue background (`#eff6ff`) and electric blue border (`#074ce0`).

### 2.4 Tab & Segmented Controls
- **Inactive Tab**: Text color `#454c58`, weight `500`.
- **Hover Tab**: Text color `#16191f`.
- **Active / Selected Tab**: Text color `#074ce0`, weight `600`, active indicator bar (`2px` height, color `#074ce0`).

---

## 3. Feedback and Validation Mechanisms

### 3.1 Inline Error Boxes
- Container: Background `#fee2e2` (red tint), border `1px solid #fecaca`, radius `8px`.
- Text: Instrument Sans Regular (`13px`), color `#dc2626`.
- Leading Icon: `Icons.error_outline` (`16px`), color `#dc2626`.

### 3.2 Toast & Snackbars
- Floating pill or container positioned at bottom or top-right.
- Background: High-contrast dark field (`#16191f`), text on field (`#fcfcfd`), radius `8px`.
- Action Button: Text in electric blue (`#38bdf8` or `#ffffff`).
- Duration: 3 seconds with subtle fade/slide in.

### 3.3 Confirmation Dialogs
- Triggered before any permanent, destructive, or administrative action (e.g., delete project, remove collaborator, leave project).
- Visuals: Clean white panel with explicit red confirmation button and neutral Cancel button.

