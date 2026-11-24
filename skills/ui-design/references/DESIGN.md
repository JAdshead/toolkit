# Design

The source of truth for how this app looks. Agents building UI use these values and nothing else; change this file first when the design changes.

## Users

- **Who:** <!-- e.g. ops engineers on a laptop, checking in many times a day -->
- **Main task:** <!-- the one thing they come to do; it gets the most visual weight -->

## Direction

- **Feel:** <!-- three adjectives, e.g. dense, calm, precise -->
- **References:** <!-- apps or sites to look like, and what to take from each -->
- **Not:** <!-- what it must not feel like, e.g. playful, marketing-heavy -->

## Tokens

Where these live in code: <!-- e.g. tailwind.config.ts, src/styles/tokens.css -->

### Colour

| Role | Value |
|---|---|
| Background | |
| Surface | |
| Border | |
| Text | |
| Text, muted | |
| Accent (one only) | |
| Success / Warning / Danger | |

Contrast: body text at least 4.5:1 against its background.

### Type

| Role | Font | Size / line height | Weight |
|---|---|---|---|
| Display | | | |
| Heading | | | |
| Body | | | |
| Small | | | |

### Spacing, radius, shadow

- **Spacing scale:** 4, 8, 12, 16, 24, 32, 48, 64 px
- **Radius:** <!-- e.g. 6px controls, 10px cards -->
- **Shadow:** <!-- one or two levels at most -->

## Layout

- **Max content width:** <!-- e.g. 1200px -->
- **Breakpoints:** 375 (mobile), 768, 1280
- **Navigation:** <!-- e.g. left sidebar on desktop, bottom bar on mobile -->

## Components

- **Library:** <!-- e.g. shadcn/ui on Radix and Tailwind -->
- **Conventions:** <!-- e.g. one primary button per screen; destructive actions confirm -->

## Don't

Banned defaults in the `ui-design` skill, plus this project's own:

- Purple, indigo or pink gradients; gradient text
- Cards inside cards; border, shadow and tinted background all on one element
- Emoji used as icons
- Everything centred; every element the same size and weight
- More than one accent colour; grey text on a coloured background
- Spacing or font sizes off the scale
- Filler copy: "Welcome to X", "Unlock the power of"
