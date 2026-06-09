---
name: Lumina Focus
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#414751'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#717783'
  outline-variant: '#c1c7d3'
  surface-tint: '#0060ac'
  primary: '#005da7'
  on-primary: '#ffffff'
  primary-container: '#2976c7'
  on-primary-container: '#fdfcff'
  inverse-primary: '#a4c9ff'
  secondary: '#5b5f63'
  on-secondary: '#ffffff'
  secondary-container: '#dde0e5'
  on-secondary-container: '#5f6368'
  tertiary: '#7f5300'
  on-tertiary: '#ffffff'
  tertiary-container: '#a06900'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#a4c9ff'
  on-primary-fixed: '#001c39'
  on-primary-fixed-variant: '#004883'
  secondary-fixed: '#e0e3e8'
  secondary-fixed-dim: '#c3c7cc'
  on-secondary-fixed: '#181c20'
  on-secondary-fixed-variant: '#43474c'
  tertiary-fixed: '#ffddb4'
  tertiary-fixed-dim: '#ffb953'
  on-tertiary-fixed: '#291800'
  on-tertiary-fixed-variant: '#633f00'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  display:
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
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-page: 24px
  stack-xl: 40px
  stack-md: 16px
  stack-sm: 8px
  inset-md: 16px
  gutter: 12px
---

## Brand & Style
The brand personality is centered on clarity, calm, and intentionality. Targeted at professionals and students who suffer from cognitive overstimulation, the UI evokes a sense of "digital breathing room." 

The design style is **Minimalism with a Soft-Tactile edge**. By utilizing heavy whitespace and a restricted color palette, the interface recedes to the background, allowing the user's tasks to become the focal point. The emotional response is one of organized tranquility—transforming a chaotic list of chores into a manageable, serene sequence of actions.

## Colors
The palette is intentionally sparse to minimize visual noise. 
- **Primary (Serene Blue):** Reserved exclusively for high-intent actions, progress indicators, and the "completed" state. 
- **Secondary (Deep Charcoal):** Used for primary headings and body text to ensure high legibility against the stark background.
- **Neutral/Surface:** A layered approach using pure white for the main canvas and soft off-white for secondary containers or grouped task lists. 

Avoid using grey for text where possible; use opacity scales of the Deep Charcoal to maintain a consistent hue throughout the interface.

## Typography
The system uses **Inter** for its systematic, utilitarian clarity. The type hierarchy relies on weight and generous line height rather than drastic size changes to maintain a sophisticated, editorial feel. 

Headlines use slight negative letter-spacing to appear tighter and more "designed," while smaller labels use increased tracking for maximum glanceability. For completed tasks, apply a strikethrough and reduce the opacity of the text to 40% to visually "clear" the item from the user's immediate attention.

## Layout & Spacing
This design system follows a **Fixed-Margin Fluid layout**. On mobile devices, a consistent 24px side margin is maintained to prevent content from feeling cramped against the screen edges. 

The vertical rhythm is driven by "Stack" units. Use `stack-xl` to separate major content groups (e.g., Today's Tasks vs. Upcoming), and `stack-md` for individual task items. Generous whitespace is the primary separator—avoid using horizontal rules (lines) unless absolutely necessary for data density; prefer using white space or subtle tonal shifts in the background.

## Elevation & Depth
Hierarchy is established through **Ambient Shadows** and **Tonal Layering**. 
- **Base Level:** The page background (#F8F9FA).
- **Surface Level:** Task cards and input containers (#FFFFFF) which use an extremely soft, diffused shadow (Blur: 20px, Y: 4px, Opacity: 4% Charcoal).
- **Active Level:** Floating Action Buttons (FABs) or active modals use a slightly more pronounced shadow (Blur: 30px, Y: 8px, Opacity: 8% Charcoal) to suggest they are physically closer to the user.

Avoid harsh borders. The transition between the background and a card should feel like a natural shift in light rather than a structural boundary.

## Shapes
The shape language is **Soft and Approachable**. A standard radius of 12px (0.75rem) is applied to all task cards and input fields. Primary action buttons and status chips use a 16px (1rem) radius to feel distinct from structural elements. This level of roundedness removes the "sharpness" of the interface, contributing to the calming brand narrative.

## Components
- **Buttons:** Primary buttons are solid Serene Blue with white text. Secondary buttons are ghost-style with a subtle Deep Charcoal 1px border at 10% opacity.
- **Task Cards:** Minimum height of 64px to ensure a large touch target. Content should be vertically centered with 16px horizontal padding.
- **Checkboxes:** Custom circular checkboxes. When unchecked, a 2px stroke in 20% Charcoal. When checked, a solid Serene Blue fill with a white checkmark icon.
- **Input Fields:** No bottom border; use a solid white background with 12px rounded corners. The placeholder text should be Deep Charcoal at 30% opacity.
- **Chips/Tags:** Used for task categories (e.g., "Work," "Personal"). These should have a light fill (5% Primary Color) and Serene Blue text, using `label-sm` typography.
- **Empty States:** Use simple, single-stroke line icons (2px weight) paired with a `body-lg` descriptor to encourage the user without overwhelming them with complex illustrations.