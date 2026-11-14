# AyhanX-Agent — Design Principles

This project follows Apple's fluid interface design principles, translated for the web.

## Core Philosophy

> "An interface feels alive when motion starts from the current on-screen value, 
> inherits the user's velocity, projects momentum forward, and can be grabbed 
> and reversed at any instant."

Every animation in this project must be **interruptible**, **velocity-aware**, and **responsive to input on pointer-down**.

## The Four Principles

1. **Response** — Kill latency. Feedback on pointer-down, not release.
2. **Direct Manipulation** — 1:1 tracking. Content follows finger exactly.
3. **Interruptibility** — Every animation can be grabbed and reversed mid-flight.
4. **Behavior over Animation** — Springs, not keyframes. New input changes target; motion stays continuous.

## Motion Tokens

```css
:root {
  /* Spring presets (Motion library) */
  --spring-snappy:  { bounce: 0,    duration: 0.2 };  /* buttons, toggles */
  --spring-gentle:  { bounce: 0,    duration: 0.4 };  /* modals, sheets */
  --spring-bouncy:  { bounce: 0.2,  duration: 0.4 };  /* momentum, flicks */
  --spring-instant: { bounce: 0,    duration: 0.1 };  /* tooltips, hovers */
  
  /* Durations (fallback for reduced-motion) */
  --duration-instant: 100ms;
  --duration-fast:    180ms;
  --duration-normal:  280ms;
  --duration-slow:    400ms;
}
