---
name: Convoy Telemetry
colors:
  surface: '#faf8ff'
  surface-dim: '#d8d9e6'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#ecedfa'
  surface-container-high: '#e6e7f4'
  surface-container-highest: '#e1e2ee'
  on-surface: '#191b24'
  on-surface-variant: '#424656'
  inverse-surface: '#2e303a'
  inverse-on-surface: '#eff0fd'
  outline: '#727687'
  outline-variant: '#c2c6d8'
  surface-tint: '#0054d6'
  primary: '#0050cb'
  on-primary: '#ffffff'
  primary-container: '#0066ff'
  on-primary-container: '#f8f7ff'
  inverse-primary: '#b3c5ff'
  secondary: '#006c4b'
  on-secondary: '#ffffff'
  secondary-container: '#60f9bd'
  on-secondary-container: '#00714f'
  tertiary: '#a33200'
  on-tertiary: '#ffffff'
  tertiary-container: '#cc4204'
  on-tertiary-container: '#fff6f4'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae1ff'
  primary-fixed-dim: '#b3c5ff'
  on-primary-fixed: '#001849'
  on-primary-fixed-variant: '#003fa4'
  secondary-fixed: '#63fcc0'
  secondary-fixed-dim: '#3fdfa5'
  on-secondary-fixed: '#002114'
  on-secondary-fixed-variant: '#005138'
  tertiary-fixed: '#ffdbd0'
  tertiary-fixed-dim: '#ffb59d'
  on-tertiary-fixed: '#390c00'
  on-tertiary-fixed-variant: '#832600'
  background: '#faf8ff'
  on-background: '#191b24'
  surface-variant: '#e1e2ee'
  telemetry-emerald: '#00C48C'
  route-cyan: '#00D4FF'
  alert-warning: '#FF9500'
  alert-critical: '#FF3B30'
  map-surface: '#F4F6F8'
  card-bg: '#FFFFFF'
  text-primary: '#1A1D20'
  text-secondary: '#636A73'
  border-subtle: '#E5E8EB'
typography:
  headline-xl:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
  telemetry-num:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 22px
    letterSpacing: -0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The design system is engineered for decentralized physical infrastructure networks (DePIN) and high-stakes collective mobility. It serves convoy pilots, fleet drivers, and active group navigators who demand instant spatial orientation and frictionless telemetry verification. 

The aesthetic adheres strictly to modern utility: edge-to-edge spatial awareness, high legibility under high-glare conditions, and zero visual clutter. It synthesizes the intuitive, battle-tested efficiency of consumer navigation operating systems with the precision telemetry of Web3 verification states. Floating pure-white surfaces hover above dynamic vector cartography, utilizing high-contrast electric blue routes and telemetry accents to direct attention without overwhelming the driver or user.

## Colors

The palette leverages a focused, hyper-visible color model optimized for quick glanceability against light vector map styling.

- **Primary (`#0066FF`)**: The electric blue anchor used for active navigation vectors, key actions, primary waypoints, and validated connectivity status.
- **Secondary / Telemetry Emerald (`#00C48C`)**: Applied exclusively to verified DePIN nodes, real-time token yield badges, and within-bounds convoy confirmations.
- **Surface & Neutrals**: Pure white (`#FFFFFF`) floating cards over light neutral cartography (`#F4F6F8`), balanced with high-contrast slate text (`#1A1D20`) for sub-second readability.
- **System States**: Warning and critical alerts use amber (`#FF9500`) and red (`#FF3B30`) for geofence breaches, lost GPS lock, or convoy dropouts.

## Typography

The type scale uses Inter across all viewports to deliver uniform, unembellished legibility across diverse hardware displays.

- **Headlines**: Semi-bold to bold weights with tight negative tracking to maintain punchy, clear direction prompts and status announcements.
- **Body**: Regular weights optimized for fast scanning of street names, distance milestones, and network confirmations.
- **Labels & Telemetry Numbers**: Dedicated high-weight, tracked labels for Web3 micro-reward tickers, geofence status badges, and convoy leader indicators. Numerals employ tabular spacing when displaying fluctuating coordinates, speed, or cryptographic validation rewards.

## Layout & Spacing

Layout adheres to a full-bleed, layered spatial structure where dynamic interactive cartography serves as the persistent infinite canvas. 

- **Layer Hierarchy**:
  1. Base Map Layer (Z-0): Vector street grid, convoy trails, and geofence meshes.
  2. Map Controls (Z-10): Floating action controls (re-center, zoom, layers) inset by `space-md` (16px) from canvas boundaries.
  3. Floating Header & Overlays (Z-20): Pill-shaped search and convoy status bars anchored to safe-area top boundaries.
  4. Bottom Sheet & Modals (Z-30): Persistent sheet docking to the bottom screen edge, housing active convoy lists and DePIN telemetry payouts.
- **Responsive Adaptations**:
  - **Mobile (<768px)**: Bottom sheet controls snap between docked peek (96px), half-expansion (40vh), and full-expansion (85vh). Floating controls stack vertically along the right safe margin.
  - **Tablet/Desktop (≥768px)**: Map remains edge-to-edge; navigation overlays and bottom sheets consolidate into a left-anchored floating utility panel (400px wide, `space-lg` inset from borders).

## Elevation & Depth

Visual depth is achieved through high-radii ambient shadow falloffs rather than opaque borders, preserving an uncluttered floating overlay aesthetic against moving map tiles.

- **Level 1 (Telemetry Chips & Subtle Badges)**:
  `box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04);`
  Provides gentle distinction for small pill badges and metadata tags.
- **Level 2 (Floating Action Buttons & Search Pills)**:
  `box-shadow: 0 4px 12px -2px rgba(15, 23, 42, 0.08), 0 2px 6px -1px rgba(15, 23, 42, 0.04);`
  Elevates interactive floating controls crisply above contrasting map terrain and route polylines.
- **Level 3 (HUD Alerts & Persistent Bottom Sheets)**:
  `box-shadow: 0 12px 32px -4px rgba(15, 23, 42, 0.12), 0 4px 12px -2px rgba(15, 23, 42, 0.06);`
  Separates major structural surfaces, creating clear spatial stratification over changing cartography.
- **Surface Treatment**:
  Floating surfaces utilize pure white (`#FFFFFF`) with an optional subtle 1px border (`rgba(0, 0, 0, 0.04)`) to maintain silhouette definition when passing over bright map sectors or satellite base layers.

## Shapes

The design system standardizes on balanced `roundedness: 2` (base 8px radius) with purposeful escalation for floating waypoints and interactive touch targets:

- **Cards & Bottom Sheets**: 16px (`rounded-lg`) corner rounding along free edges, providing friendly tactile softness while maintaining utilitarian efficiency.
- **Interactive Controls & Search Modules**: Fully rounded (pill geometry) for search bars, rider tooltips, and floating operational badges to distinctly contrast against rectangular buildings and geometric street grids.
- **Map Nodes**: Circular 32px to 44px round avatars representing active nodes and convoy participants, framed by dynamic colored radar rings.

## Components

- **Buttons**:
  - *Primary*: Background `#0066FF`, white text, 8px radius (`rounded`), height 48px, semi-bold font. Fully tactile with active state depression (`scale(0.98)`).
  - *Secondary / Utility*: Floating circular action buttons (FAB) in `#FFFFFF` with Level 2 elevation, housing 20px monochrome icons (e.g., location crosshair, group voice toggle).

- **Search & Navigation Pill**:
  - Floating 52px high pill bar with Level 2 shadow. Houses system drawer icon left, placeholder text center, and Web3 wallet address / status pill right.

- **Convoy HUD Alert**:
  - Floating 12px (`rounded-lg`) high-contrast card anchored 16px below the top pill. Displays situational changes (e.g., "Rider 03 breached geofence boundary") with warning-tinted indicator dots and dismiss actions.

- **Convoy Bottom Sheet**:
  - Pure white card docking to viewport bottom. Top edges rounded to 24px (`rounded-xl`). Features a centered drag indicator pill (36px x 4px in subtle gray).
  - Contains active rider list, collective speed metrics, and the DePIN telemetry reward tracker.

- **Telemetry & Reward Badges**:
  - Compact pills combining an emerald circle ping (`#00C48C`) with live token earnings ticker (`+4.2 NAV/hr`). Set against an ultra-soft emerald tint (`rgba(0, 196, 140, 0.10)`).

- **Map Pins & Convoy Markers**:
  - Live rider pins styled as 36px white circular discs with colored profile ring or avatar. Tooltip pill fixed above displaying rider moniker and relative distance (`+120m`).