# [URGENT] Fix Gemini Model Error
The app is currently failing because it's trying to use `gemini-2.0-flash` (or `gemini-3.5-flash` in some files) which is invalid. I am rolling it back to the stable `gemini-1.5-flash`.

# Premium UI/UX Transformation

## Proposed Changes

### 1. Advanced Animations & Micro-interactions
- **Tilt Effect:** Add a 3D tilt response to Dashboard cards based on tap position.
- **Hero Transitions:** Smooth transitions from Dashboard to Note Editor and 3D Explorer.
- **Haptics:** Precise `lightImpact` and `success` vibrations on key interactions.

### 2. AI-Specific UX (The "Breathe" Effect)
- **Streaming Text:** Implement word-by-word streaming for AI responses.
- **Heartbeat Pulse:** Replace the "Thinking" spinner with a soft, pulsing border glow around the chat.
- **Contextual Chips:** Add "Explain like I'm 5", "Analogy", and "Summary" chips to the chat.

### 3. Glassmorphism & Spatial Depth
- **Frosted Stack:** Update `MainNavigation` with high-sigma blur and a thin reflective border.
- **Ambient Glow:** Add dynamic background glows that change color based on the feature (e.g., Purple for Notes, Orange for Quiz).

### 4. 3D Trophy Room (Gamification)
- **3D Relics:** Update the Profile/Trophy section to allow users to rotate 3D artifacts they've earned.

## Verification Plan
1. **API Fix:** Verify `sendMessageToTutor` works without the "model unavailable" error.
2. **Streaming:** Verify text appears progressively in the chat.
3. **Animations:** Manually check the "Tilt" effect on Dashboard cards.
