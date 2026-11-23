# TeamSync — Shared Component Specifications

This specification establishes the visual styling, dimensions, properties, and states for all reusable UI components across TeamSync.

---

## 1. Buttons & Interactive Controls

### 1.1 Button Hierarchy

| Variant | Surface Fill | Text / Icon Color | Border | Height / Radius | Usage |
|---|---|---|---|---|---|
| **Primary Button** | `--dp-color-accent` (`#074ce0`) | `#ffffff` | None | `44px` / `8px` (`--dp-radius-md`) | Primary actions (Create, Submit, Save, Join Call) |
| **Secondary Button**| `--dp-color-panel` (`#ffffff`) | `--dp-color-ink` (`#16191f`) | 1px solid `--dp-color-rule` (`#dde0e6`) | `44px` / `8px` | Secondary options, Cancel, Back, Filters |
| **Tertiary / Ghost**| Transparent | `--dp-color-ink-secondary` (`#454c58`) | None | `36px` / `6px` | Inline actions, table row actions, dismiss |
| **Danger Button** | `#dc2626` | `#ffffff` | None | `44px` / `8px` | Destructive operations (Delete project, remove user) |
| **Danger Outline** | Transparent | `#dc2626` | 1px solid `#fca5a5` | `36px` / `6px` | Reject request, soft destructive controls |

### 1.2 Button States
- **Normal**: Full opacity, standard surface and border.
- **Hover**: 
  - Primary: Darkened blue (`#063ec0`), subtle `-1px` lift.
  - Secondary: Pale grey ground fill (`#f3f4f6`), rule border darkened to `#cfd4dc`.
- **Focus**: Visible 2px electric blue focus ring (`#074ce0` with 30% alpha offset).
- **Pressed**: Neutral position, 0.98 scale or darkened background.
- **Disabled**: Background `#e5e7eb`, text `#9ca3af`, cursor not-allowed, no hover interaction.
- **Loading**: Replaces button label with centered circular spinner (`strokeWidth: 2`, white or accent blue).

---

## 2. Input Fields & Form Controls

### 2.1 Text Fields & Textareas
- **Surface Fill**: `--dp-color-panel` (`#ffffff`) or subtle `--dp-color-ground-muted` (`#f3f4f6`).
- **Border**:
  - Default: 1px solid `--dp-color-rule` (`#dde0e6`).
  - Focused: 1.5px solid `--dp-color-accent` (`#074ce0`).
  - Error: 1px solid `#dc2626`.
- **Border Radius**: 8px (`--dp-radius-md`).
- **Typography**: Instrument Sans (`14.5px`), color `--dp-color-ink` (`#16191f`).
- **Placeholder / Hint**: Instrument Sans (`14px`), color `#94a3b8`.
- **Content Padding**: Horizontal `14px`, Vertical `12px` (single line) or `14px` (multiline).
- **Validation Message**: Instrument Sans (`12px`), color `#dc2626`, top offset `4px`.

### 2.2 Checkboxes, Switches, & Radios
- **Checkbox**:
  - Size: `18px` square, `4px` radius.
  - Checked: Background `--dp-color-accent` (`#074ce0`), checkmark white.
  - Unchecked: White surface, 1.5px border `#dde0e6`.
- **Switch**:
  - Active Track: `--dp-color-accent` (`#074ce0`).
  - Inactive Track: `#dde0e6`.
  - Thumb: Pure white (`#ffffff`) with subtle drop shadow.

---

## 3. Cards & Surface Containers

### 3.1 Standard Card (`AppCard` / `ProjectCard`)
- **Background**: `--dp-color-panel` (`#ffffff`).
- **Border**: 1px solid `--dp-color-rule` (`#dde0e6`).
- **Border Radius**: 12px (`--dp-radius-panel`).
- **Padding**: 16px standard (`--dp-spacing-md`), 20px for spacious headers.
- **Shadow**: `BoxShadow(color: Color(0x0816191F), blurRadius: 6, offset: Offset(0, 2))`.

### 3.2 Feature / Banner Card
- **Background**: Soft gradient or solid white with an electric-blue accent bar or icon medallion.
- **Border**: 1px solid `--dp-color-rule` (`#dde0e6`).
- **Padding**: 20px.

---

## 4. Badges, Tags, & Status Pills

| Badge Type | Background Fill | Text Color | Typography | Border | Example Usage |
|---|---|---|---|---|---|
| **Public Project** | `#dcfce7` (soft green) | `#15803d` | Instrument Sans 11px SemiBold | None | Project visibility |
| **Private Project**| `#f3f4f6` (soft grey) | `#454c58` | Instrument Sans 11px SemiBold | 1px solid `#dde0e6` | Project visibility |
| **Active / Live** | `#dbeafe` (soft blue) | `#074ce0` | Instrument Sans 11px Bold | None | Active meeting, ongoing call |
| **Pending** | `#fef3c7` (soft amber) | `#b45309` | Instrument Sans 11px SemiBold | None | Join request pending |
| **Admin** | `#eff6ff` (pale blue) | `#074ce0` | Instrument Sans 11px Bold | None | Project creator / role badge |
| **Skill Tag** | `#f3f4f6` (pale grey) | `--dp-color-ink` | Instrument Sans 12px Medium | 1px solid `#dde0e6` | Project required skills |

---

## 5. User Avatars

### 5.1 Avatar Specification
- **Shape**: Perfect circle (`--dp-radius-full`).
- **Sizes**:
  - Small: `28px` (in chat timestamps, compact lists).
  - Medium: `36px` (standard card rows, channel messages).
  - Large: `56px` (profile header).
- **Background**: Pale blue `#eff6ff` or tinted ground.
- **Initials**:
  - Font: Host Grotesk Bold (`fontSize: size * 0.38`).
  - Color: `--dp-color-accent` (`#074ce0`).
- **Border**: 1px solid `#dde0e6` or white outline.
- **Network Image**: Clipped oval with fallback to initials on error or loading.

---

## 6. App Bars & Headers (`SimpleAppBar`)

### 6.1 Specification
- **Height**: `56px` to `60px`.
- **Background**: `--dp-color-panel` (`#ffffff`) or seamless `--dp-color-ground` (`#fcfcfd`).
- **Bottom Border**: 1px solid `--dp-color-rule` (`#dde0e6`).
- **Title**: Host Grotesk SemiBold (`18px`), color `--dp-color-ink` (`#16191f`).
- **Back Button**: Icon button with `Icons.arrow_back_ios_new` (`18px`), color `--dp-color-ink`.
- **Actions**: Icon buttons (`20px`) with `--dp-color-ink` or primary CTA buttons.

---

## 7. Dialogs, Modals, & Bottom Sheets

### 7.1 Dialogs (`AlertDialog`)
- **Background**: Pure white (`#ffffff`).
- **Border Radius**: 16px (`--dp-radius-lg`).
- **Border**: 1px solid `--dp-color-rule` (`#dde0e6`).
- **Title**: Host Grotesk Bold (`18px`), color `--dp-color-ink` (`#16191f`).
- **Content**: Instrument Sans Regular (`14px`), color `--dp-color-ink-secondary` (`#454c58`).
- **Actions**: Spaced at bottom with secondary Cancel button and primary Action button.

### 7.2 Bottom Sheets
- **Background**: Pure white (`#ffffff`).
- **Top Corners**: 20px radius.
- **Drag Handle**: Centered grey pill (`36px` wide, `4px` tall, `#dde0e6`).
- **Header**: Host Grotesk SemiBold (`18px`) with close icon button.

---

## 8. Skeletons, Loaders, & Empty States

### 8.1 Loading Indicators
- **Standard**: CircularProgressIndicator with `strokeWidth: 2.5`, color `--dp-color-accent` (`#074ce0`).
- **Linear Progress**: 4px height, background `#dde0e6`, value color `--dp-color-accent` (`#074ce0`).

### 8.2 Empty State Widget (`EmptyState`)
- **Icon Container**: `64px` circular container, background `--dp-color-ground-muted` (`#f3f4f6`).
- **Icon**: `28px`, color `--dp-color-ink-secondary` (`#454c58`).
- **Title**: Host Grotesk SemiBold (`16px`), color `--dp-color-ink` (`#16191f`).
- **Subtitle**: Instrument Sans Regular (`13px`), color `--dp-color-ink-secondary` (`#454c58`), center aligned.
- **Optional CTA**: Secondary or primary button positioned below subtitle.

