# Agent Beacon UI Specification

## 1. Default Menu Bar Top Panel

The default UI is a monochrome macOS menu bar icon. Clicking it opens a compact horizontal `1x4` top panel below the menu bar item.

```text
[green count] [yellow count] [red count] [running count]
```

Hard requirements:

- The layout is one row and four columns.
- It is not `2x2`.
- It is not a single global status light.
- Each status light contains the count centered inside the light.
- Count `0` remains visible.
- No text labels are shown in default state.
- No platform logos are shown in default state.
- No thread names are shown in default state.
- The menu bar icon itself is monochrome/template-only and does not show counts or colors.

## 2. Status Order

The status order is fixed:

1. Green: completed.
2. Yellow: waiting for user action.
3. Red: failed or stuck.
4. Running: executing.

This order makes completed work visible first, followed by attention states, then active execution.

## 3. Visual Treatment

### Yellow Light

- Represents waiting for user review, input, approval, or authorization.
- Uses a warm yellow fill.
- Count is centered and readable.

### Red Light

- Represents failed, stuck, disconnected, or timed-out tasks.
- Uses a red fill.
- Count is centered and readable.

### Running Indicator

- Represents active execution.
- Uses a spinner, rotating ring, or breathing light.
- Count is centered inside or visually anchored at the center.
- It must remain readable while animating.

### Green Light

- Represents completed or normally ended tasks.
- Uses a green fill.
- Count is centered and readable.

## 4. Expanded Task List

The expanded list appears when the user hovers over the opened top panel.

Each row contains exactly:

```text
[platform logo] [thread name] [single status indicator]
```

Expanded rows must not show:

- Status words.
- Logs.
- Timestamps.
- File paths.
- Token counts.
- Elapsed time.
- Error details.
- Task commands.

## 5. Expanded Row Layout

- Platform logo is left-aligned.
- Thread name is single-line by default.
- Long thread names truncate with ellipsis.
- Status indicator is right-aligned.
- Row height stays stable across states.
- Hover state may highlight the row.
- Clicking a row activates the task target.

## 6. Interactions

### Hover

- Hovering over the opened top panel expands the task list.
- Moving away closes the panel after a short delay.

### Click

- Clicking the menu bar icon toggles the top panel.
- Clicking a task row activates its app/window/URL target.
- Clicking a task row closes the top panel.

### Drag

- The default top panel is not draggable.
- The optional desktop floating strip remains draggable, remembers its position, and is clamped to the visible screen on launch.

### Context Menu

Right-clicking the menu bar icon opens a small menu:

- Connect Installed Agents.
- Open Status File.
- Show Desktop Floating Strip.
- Show Codex/Cursor Local History.
- Quit Agent Beacon.

## 7. Empty States

When there are no tasks:

```text
[green 0] [yellow 0] [red 0] [running 0]
```

The expanded list may show a minimal empty row such as "No agent tasks", but the main default panel remains numeric and label-free.

## 8. Accessibility

- Counts must remain readable on light and dark desktop backgrounds.
- The top panel should have enough contrast against desktop content.
- The app should expose accessible labels for screen readers even though visible labels are hidden.
- Keyboard navigation for the expanded list is desirable in a later release.
