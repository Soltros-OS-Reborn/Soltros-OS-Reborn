# SoltrOS Reborn Native Setup Design System

## 0. Research Log

- Embedded references: shortlisted Apple Setup Assistant, IBM Carbon onboarding, and Notion warm minimalism; selected the operational taste discipline plus Apple Setup Assistant's sequential disclosure because first-run setup needs confidence and one decision at a time.
- Native reference: GNOME Human Interface Guidelines and libadwaita are the implementation source of truth for window chrome, preferences, status, focus, and adaptive behavior across all four desktop variants.
- Existing assets: the SoltrOS watermark remains the only branded focal image; the desktop theme supplies all other icons and materials.
- Lazyweb: skipped because this is a native GTK application rather than a browser surface; no web layout or interaction is being copied.
- Imagen drafts: skipped because native toolkit rendering and the existing brand asset are the fidelity contract, not a generated bitmap.

## 1. Atmosphere and Identity

The setup experience is a calm system checkpoint: focused, trustworthy, and reversible. Its signature is a persistent sense of progress without pressure. Each page asks for one coherent class of decisions, explains when networking or authentication is required, and never disguises a long-running operation as instant work.

## 2. Color

The application inherits the active libadwaita light or dark palette. It does not define raw colors.

| Role | Token | Usage |
| --- | --- | --- |
| Primary surface | `AdwStyleManager` window surface | Page background |
| Secondary surface | `card` style class | Preference groups and review summaries |
| Accent | System accent | Primary action, switches, focus |
| Success | `success` semantic class | Completed setup state |
| Warning | `warning` semantic class | Offline or deferred work |
| Error | `error` semantic class | Failed setup task |

Accent color is reserved for interactive state and completion progress. Status color is always paired with an icon and text.

## 3. Typography

The system UI font is used at every level so the application follows KDE, GNOME, and Niri user preferences.

| Level | Native style | Usage |
| --- | --- | --- |
| Display | `title-1` | Welcome and terminal completion states |
| Section title | `title-2` | Current setup stage |
| Group title | `AdwPreferencesGroup` title | Related decisions |
| Body | Native body | Explanations and log output |
| Caption | `caption` | Network, authentication, and persistence notes |
| Monospace | `monospace` | Command output only |

No body copy is made smaller than the toolkit default.

## 4. Spacing and Layout

Spacing uses a six-pixel native rhythm.

| Token | Value | Usage |
| --- | --- | --- |
| `SPACE_XS` | 6 | Icon-to-label and compact gaps |
| `SPACE_SM` | 12 | Row and button clusters |
| `SPACE_MD` | 18 | Page insets and status spacing |
| `SPACE_LG` | 24 | Major group separation |
| `SPACE_XL` | 36 | Welcome focal spacing |

- Default window: 760 by 620 logical pixels.
- Minimum window: 480 by 520 logical pixels.
- Content clamp: 680 logical pixels.
- Every page owns its vertical scrolling; the header and action bar remain visible.
- Compact widths use one column without horizontal scrolling or truncated primary labels.

## 5. Components

### Setup Shell

- Structure: native header bar, stage title, progress indicator, scroll-owned page stack, and persistent action bar.
- States: first page, intermediate page, review, applying, completed, partial failure.
- Accessibility: deterministic tab order, Alt+Left for Back, Alt+Right for Continue, and a visible focus ring supplied by the toolkit.
- Motion: native crossfade or slide transition; disabled automatically when reduced motion is active.

### Preference Group

- Structure: `AdwPreferencesGroup` containing entry, combo, or switch rows.
- States: default, focused, selected, disabled while offline, validation error.
- Accessibility: row titles remain visible labels; subtitles carry requirements without relying on color.

### Network Banner

- Structure: `AdwBanner` above the software page.
- States: hidden when online, revealed when offline.
- Accessibility: contains explicit text and does not take keyboard focus.

### Review Summary

- Structure: grouped action rows generated from the validated task model.
- States: empty selection, selected tasks, privileged task marker, network task marker.
- Accessibility: summaries use readable task names rather than command lines.

### Execution Status

- Structure: compact horizontal status icon, title and current task, followed by a progress bar and expandable monospace output.
- States: idle, running, success, partial failure.
- Empty output: the log surface is hidden when no command ran; it never becomes an empty focal card.
- Accessibility: status changes update text as well as iconography; the log is selectable and keyboard-scrollable.

## 6. Motion and Interaction

- Button and row feedback uses toolkit-native micro interaction timing.
- Page changes use the toolkit's standard transition and never animate layout geometry manually.
- Starting work locks navigation so the same task set cannot run twice concurrently.
- Closing during execution is blocked with an explanatory toast.
- Long-running output is streamed without blocking the GTK main loop.
- Reduced-motion behavior follows GTK settings; no custom animation overrides it.

## 7. Depth and Surface

The depth strategy is tonal shift. Native window, header, preferences groups, banners, dialogs, and popovers receive their hierarchy from libadwaita. No custom shadows, glass effects, decorative borders, or gradients are introduced.

## 8. Accessibility Constraints and Accepted Debt

### Constraints

- Target WCAG 2.2 AA semantics where the native toolkit exposes equivalent behavior.
- Full keyboard reachability and visible native focus are mandatory.
- No state relies on color alone.
- Controls remain usable at 200 percent text scaling and at the minimum window size.
- Network-dependent controls are disabled with an explanatory banner while offline.
- Secret material, passwords, tokens, and command environment values never appear in persistent state.
- Setup completion is written only after all selected tasks succeed or the user explicitly chooses to defer setup.

### Accepted Debt

| Item | Location | Why accepted | Owner / Exit |
| --- | --- | --- | --- |
| Native visual behavior differs slightly by desktop theme | Whole application | The cross-desktop contract intentionally follows the user's system theme | Revisit only if a desktop theme causes an accessibility regression |
