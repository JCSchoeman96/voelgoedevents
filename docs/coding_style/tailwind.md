# Tailwind CSS Coding Style Guide

## Purpose

This guide defines how Tailwind CSS is used for styling and layout in VoelgoedEvents. Tailwind is the project's utility-first CSS framework, providing a consistent, responsive design system with world-class UI capabilities.

## Design Principles

### World-Class UI Design

VoelgoedEvents aims for **premium, polished interfaces** with:

- **Subtle micro-interactions** – smooth hover effects, transitions, and animations
- **Clean typography and spacing** – refined, balanced layout
- **Delightful details** – loading states, visual feedback, elegant error messaging
- **Responsive excellence** – beautiful across all devices
- **No generic components** – avoid daisyUI and similar pre-made component libraries; build hand-crafted Tailwind components

Every button click, form field, and card should feel intentional and well-designed.

## Tailwind Philosophy

### Utility-First Approach

Compose styles by combining utility classes directly in HTML/HEEx templates. Do not create custom CSS classes for common patterns.

```heex
<!-- Good: Utility composition -->
<button class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition">
  Click me
</button>

<!-- Avoid: Creating custom classes -->
<style>
  .primary-button { /* multiple properties */ }
</style>
<button class="primary-button">Click me</button>
```

### Why Utility-First?

1. **Speed** – No context-switching between HTML and CSS files.
2. **Consistency** – Colors, spacing, and typography are defined once in the Tailwind config.
3. **Scalability** – Adding styles doesn't create unused CSS or naming conflicts.
4. **Maintainability** – CSS is co-located with markup; styles are easy to find and update.

## Tailwind v4 Configuration

### CSS Import Syntax

Tailwind v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

```css
@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/my_app_web";
```

**Always use and maintain this import syntax** in the `app.css` file for projects generated with `phx.new`.

### Never Use `@apply`

`@apply` defeats the purpose of utility-first CSS. Avoid it entirely.

```css
/* ❌ NEVER do this */
@apply flex items-center justify-center p-4 bg-blue-500;

/* ✅ Instead: Use utilities directly in HTML/HEEx */
<div class="flex items-center justify-center p-4 bg-blue-500">
  Content
</div>
```

## Asset Bundling and JavaScript

### No Inline Scripts in Layouts

- **Never** write inline `<script>` tags within layout templates
- **Never** reference external vendor `<script>` src or `<link>` href in layouts
- **Must** import vendor dependencies into `app.js` and `app.css`

```heex
<!-- ❌ BAD: Inline script in layout -->
<script>
  console.log('This should not be here');
</script>

<!-- ❌ BAD: External vendor script in layout -->
<script src="https://cdn.example.com/vendor.js"></script>

<!-- ✅ GOOD: Import vendor in app.js -->
<!-- In assets/js/app.js -->
import { vendorFunction } from './vendor/something.js';

<!-- Then use it through your hooks/components -->
```

Only `app.js` and `app.css` bundles are supported out of the box.

## Class Organization

### Order and Readability

When using multiple utility classes, organize them logically:

```heex
<!-- Good: Layout → Spacing → Colors → Effects -->
<div class="
  flex flex-col items-center justify-between
  p-4 gap-2
  bg-white text-gray-900
  rounded-lg shadow-md
  hover:shadow-lg transition
">
  Content
</div>

<!-- Also acceptable: One class per line for very long class lists -->
<article class="
  max-w-2xl
  mx-auto
  p-6
  bg-gradient-to-r from-blue-50 to-indigo-50
  rounded-xl
  shadow-lg
  border-l-4 border-blue-500
">
  Content
</article>
```

### Using `class={[ ... ]}` Lists in HEEx

For dynamic classes, use lists for clarity:

```heex
<div class={[
  "flex p-4 rounded-lg",
  @expanded? && "bg-blue-100",
  @disabled? && "opacity-50 cursor-not-allowed",
  @size == :large && "p-8 text-lg",
  @size == :small && "p-2 text-sm"
]}>
  Content
</div>
```

Or compute in LiveView:

```elixir
def get_button_classes(size, disabled?) do
  size_classes = case size do
    :small -> "px-3 py-1 text-sm"
    :large -> "px-6 py-3 text-lg"
    _ -> "px-4 py-2"
  end
  
  disabled_classes = if disabled?, do: "opacity-50 cursor-not-allowed", else: ""
  
  "#{size_classes} #{disabled_classes} bg-blue-500 text-white rounded hover:bg-blue-600"
end
```

```heex
<button class={get_button_classes(@size, @disabled?)}>
  Click me
</button>
```

## Layout Patterns

### Flexbox and Grid

Use Tailwind's Flexbox and Grid utilities for layout. Avoid floats and absolute positioning when possible.

```heex
<!-- Good: Flex for simple layouts -->
<nav class="flex items-center justify-between p-4">
  <.logo />
  <.nav_links />
  <.user_menu />
</nav>

<!-- Good: Grid for complex layouts -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <%= for card <- @cards do %>
    <.card data={card} />
  <% end %>
</div>

<!-- Good: Flex with gap for spacing -->
<div class="flex flex-col gap-4">
  <h1>Title</h1>
  <p>Description</p>
  <.action_buttons />
</div>

<!-- Avoid: Using floats or absolute positioning for layout -->
<div style="float: left; width: 50%">
  <!-- Don't do this -->
</div>
```

### Responsive Design

Use Tailwind's responsive prefixes. Mobile-first approach: start with mobile styles, then layer tablet/desktop overrides.

```heex
<!-- Good: Mobile-first, responsive -->
<div class="
  grid
  grid-cols-1
  sm:grid-cols-2
  lg:grid-cols-3
  xl:grid-cols-4
  gap-4
">
  <%= for item <- @items do %>
    <.item_card item={item} />
  <% end %>
</div>

<!-- Good: Text sizes responsive -->
<h1 class="text-xl sm:text-2xl lg:text-3xl font-bold">
  <%= @title %>
</h1>

<!-- Good: Responsive padding -->
<section class="p-4 sm:p-6 lg:p-8 xl:p-12">
  Content
</section>

<!-- Avoid: Desktop-first (outdated) -->
<div class="md:grid-cols-2">
  <!-- Missing mobile context -->
</div>
```

## Typography

### Font Sizes and Weights

```heex
<!-- Good: Using Tailwind's typographic scale -->
<h1 class="text-4xl font-bold">Page Title</h1>
<h2 class="text-2xl font-semibold">Section Header</h2>
<p class="text-base leading-relaxed">
  Body text with good line height for readability.
</p>
<small class="text-sm text-gray-600">Minor text</small>

<!-- Avoid: Arbitrary sizes -->
<h1 style="font-size: 42px">Title</h1>
```

### Color Usage

```heex
<!-- Good: Using the color palette -->
<p class="text-blue-600">Primary action</p>
<p class="text-gray-500">Secondary text</p>
<p class="text-red-600">Error message</p>
<p class="text-green-600">Success message</p>

<!-- Good: Backgrounds and text combinations -->
<div class="bg-blue-100 text-blue-900 p-4 rounded">
  Informational message
</div>

<div class="bg-green-50 text-green-800 border-l-4 border-green-400 p-4">
  Success notification
</div>

<!-- Avoid: Relying on arbitrary colors -->
<p style="color: #f0a500">Text</p>
```

## States and Interactions

### Hover, Focus, and Active States

```heex
<!-- Good: Using state variants -->
<button class="
  bg-blue-500 text-white px-4 py-2 rounded
  hover:bg-blue-600
  focus:outline-none focus:ring-2 focus:ring-blue-400 focus:ring-offset-2
  active:bg-blue-700
  disabled:opacity-50 disabled:cursor-not-allowed
  transition
">
  Click me
</button>

<!-- Good: Link states -->
<.link class="
  text-blue-600
  hover:text-blue-800
  hover:underline
  focus:outline-none focus:ring-2 focus:ring-blue-400 rounded
" href={~p"/"}>
  Home
</.link>

<!-- Good: Form input states -->
<input
  type="text"
  class="
    px-4 py-2 border border-gray-300 rounded
    focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent
    placeholder:text-gray-400
  "
  placeholder="Enter text..."
/>
```

### Transitions

```heex
<!-- Good: Smooth transitions for interactions -->
<div class="
  bg-blue-500 text-white p-4 rounded
  hover:bg-blue-600
  transition duration-200 ease-in-out
">
  Hover me
</div>

<!-- Good: Transform on hover -->
<div class="
  p-4 bg-white rounded shadow
  hover:shadow-lg hover:scale-105
  transition duration-300 transform
">
  Interactive card
</div>
```

## Spacing and Sizing

### Consistent Spacing

Use Tailwind's spacing scale: `px-1`, `px-2`, `px-4`, `px-6`, `px-8`, etc.

```heex
<!-- Good: Consistent spacing -->
<div class="p-4 space-y-4">
  <h2 class="text-xl font-semibold">Heading</h2>
  <p>Paragraph with even spacing between siblings</p>
  <p>Another paragraph</p>
</div>

<!-- Good: Using gap for flex/grid -->
<div class="flex flex-col gap-4">
  <.input />
  <.input />
  <.button>Submit</.button>
</div>

<!-- Avoid: Arbitrary spacers -->
<div style="margin: 23px; padding: 17px;">
  <!-- Don't use arbitrary values -->
</div>
```

### Max-Width and Containers

```heex
<!-- Good: Responsive max-width -->
<div class="max-w-2xl mx-auto px-4">
  <!-- Content centered, responsive padding -->
</div>

<!-- Good: Container for full-width sections -->
<section class="w-full bg-blue-50 py-12">
  <div class="max-w-4xl mx-auto px-4">
    <!-- Content constrained but section spans full width -->
  </div>
</section>
```

## Form Styling

### Form Inputs and Buttons

```heex
<!-- Good: Consistent form styling -->
<form class="space-y-4">
  <div>
    <label class="block text-sm font-medium text-gray-700 mb-1">
      Event Name
    </label>
    <input
      type="text"
      class="
        w-full px-4 py-2
        border border-gray-300 rounded-lg
        focus:outline-none focus:ring-2 focus:ring-blue-500
        placeholder:text-gray-400
      "
      placeholder="Enter event name"
    />
  </div>

  <div>
    <label class="block text-sm font-medium text-gray-700 mb-1">
      Description
    </label>
    <textarea
      class="
        w-full px-4 py-2
        border border-gray-300 rounded-lg
        focus:outline-none focus:ring-2 focus:ring-blue-500
        placeholder:text-gray-400
        resize-vertical
      "
      placeholder="Event description"
      rows="4"
    ></textarea>
  </div>

  <button class="
    w-full px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg
    hover:bg-blue-700
    focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
    transition
  ">
    Create Event
  </button>
</form>
```

## Cards and Components

### Common Component Patterns

```heex
<!-- Good: Card component -->
<div class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition">
  <h3 class="text-lg font-semibold mb-2"><%= @title %></h3>
  <p class="text-gray-600"><%= @description %></p>
  <.link class="text-blue-600 hover:text-blue-800 mt-4 inline-block" href={@link}>
    Learn more →
  </.link>
</div>

<!-- Good: Alert component -->
<div class="
  bg-yellow-50 border-l-4 border-yellow-400
  p-4 rounded-r-lg
">
  <h4 class="text-sm font-semibold text-yellow-800">Warning</h4>
  <p class="text-sm text-yellow-700"><%= @message %></p>
</div>

<!-- Good: Badge component -->
<span class="
  inline-block
  px-3 py-1 text-sm font-semibold
  bg-blue-100 text-blue-800 rounded-full
">
  <%= @label %>
</span>
```

## Performance and Best Practices

### ✅ Use Purge/Content Configuration

Ensure Tailwind purges unused styles in production. Configure `content` in `tailwind.config.js`:

```javascript
module.exports = {
  content: [
    './lib/**/*.{ex,html,js}',
    './lib/**/*.heex',
    './assets/**/*.{js,jsx,ts,tsx}',
  ],
  theme: { /* ... */ },
  plugins: [],
};
```

### ✅ Customize the Theme

Extend Tailwind's default theme with project-specific values:

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          primary: '#2563eb',
          secondary: '#10b981',
        },
      },
      spacing: {
        '72': '18rem',
        '96': '24rem',
      },
      borderRadius: {
        'xl': '1rem',
      },
    },
  },
};
```

Then use in templates:

```heex
<button class="bg-brand-primary hover:bg-brand-secondary px-6 py-3 rounded-xl">
  Click
</button>
```

## Accessibility

### Color Contrast

Ensure sufficient contrast between text and background.

```heex
<!-- Good: High contrast -->
<p class="text-gray-900 bg-white">High contrast</p>

<!-- Avoid: Low contrast -->
<p class="text-gray-400 bg-gray-50">Poor contrast</p>
```

### Focus States

Always provide visible focus indicators for keyboard navigation.

```heex
<button class="
  px-4 py-2 bg-blue-600 text-white rounded
  focus:outline-none
  focus:ring-2 focus:ring-blue-400 focus:ring-offset-2
">
  Click me
</button>

<a href="#" class="
  text-blue-600 hover:text-blue-800
  focus:outline-none focus:ring-2 focus:ring-blue-400 rounded px-1
">
  Link
</a>
```

### Semantic HTML with Tailwind

```heex
<!-- Good: Semantic HTML + Tailwind -->
<nav class="flex items-center justify-between p-4 bg-gray-800">
  <h1 class="text-white font-bold">Logo</h1>
  <ul class="flex gap-4">
    <li><a href="/" class="text-gray-100 hover:text-white">Home</a></li>
    <li><a href="/about" class="text-gray-100 hover:text-white">About</a></li>
  </ul>
</nav>

<!-- Good: Proper form structure -->
<form class="space-y-4">
  <div>
    <label for="email" class="block text-sm font-medium text-gray-700">
      Email
    </label>
    <input
      id="email"
      type="email"
      aria-required="true"
      class="w-full px-4 py-2 border rounded focus:ring-2 focus:ring-blue-500"
    />
  </div>
</form>
```

---

*Last updated: 2025-11-25*