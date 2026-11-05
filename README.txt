EXTREME RACING 3D — VERSION 0.3.0 (SUPERCAR MODEL UPGRADE)
===========================================================

PROJECT
- Godot 4.x project; Compatibility renderer for broad Android support.
- Landscape 1280x720 interface.
- Target device: Vivo Y17s (Android; test on the actual phone).
- Original runtime-generated vehicle geometry; no copied Asphalt/Gameloft assets.

NEW IN VERSION 0.3.0
- Added scripts/car_model.gd, a reusable original 3D supercar model builder.
- Four different body proportions/styles: Vortex S1, Apex GT, Comet R and Titan X.
- Sculpted tapered body hull, hood and rear deck panels, low roof, dark glass, side windows,
  mirrors, side skirts, LED-style lights, vents, splitter, diffuser and optional rear wing.
- Three alloy rim finishes with low-poly spoke details.
- Wheels use MultiMesh instances; body parts are batched by material to reduce draw calls.
- Garage preview camera now shows a front three-quarter view on a display plinth.
- Preview and race lighting avoid real-time shadows to reduce GPU cost on entry-level phones.
- AI traffic cars now move and recycle ahead of the player during a race.
- LAN join screen now has an editable host IP field and connection/disconnection status text.
- Upgrade buttons show MAXED at level 5; added RESET TUNING button.

GARAGE FEATURES RETAINED
- Four selectable original prototype cars.
- Rotating 3D garage preview.
- Six paint colours.
- Spoiler on/off and three wheel finishes.
- Engine, handling and nitro upgrade levels (0–5).
- Local save at user://garage.cfg.
- START RACE and return-to-GARAGE flow.

RACING FEATURES
- Procedural city road, lane markings, barriers, buildings and two moving AI traffic cars.
- Touch steering, gas, brake and nitro controls.
- Keyboard testing: A/D or arrow keys to steer, W/up to accelerate, S/down to brake, Space for nitro.
- Experimental ENet LAN host/join path on port 24560. Enter the host phone's local Wi-Fi IPv4
  address in the IP field on the joining phone. Both phones must use the same Wi-Fi network.

IMPORTANT LIMITATIONS
- This is a playable prototype project, not a finished commercial racing game.
- Cars are original procedural low-poly models, not photorealistic sculpted production assets.
- AI cars are simple moving traffic visuals; there is no full opponent racing AI, collision damage,
  lap system, championship progression, economy or online matchmaking yet.
- LAN networking currently sends player transform updates only. It has not been tested between
  two physical Android phones and is not internet multiplayer. There is no public server, lobby,
  account system, authoritative race simulation, relay or anti-cheat.
- No APK is included. The project must be opened and exported with Godot and Android build tools.
- The project files and scene references were statically inspected for this delivery, but no Godot
  executable is available in this environment, so engine import, runtime gameplay and APK export
  have NOT been run or verified here.

OPEN ON ANDROID
1. Extract this ZIP into a normal folder on the phone.
2. Install Godot Android Editor from https://godotengine.org/download/android/.
3. In Godot Android Editor, import/open project.godot from the extracted folder.
4. Open the project and press Run. The garage should open first.
5. Select a car, paint, spoiler/wheels and performance upgrades; press START RACE.

BUILD AN ANDROID APK (RECOMMENDED DESKTOP ROUTE)
1. Install Godot 4.x on Windows, Linux or macOS and install matching export templates.
2. Install OpenJDK 17 and Android Studio / Android SDK.
3. In Godot Editor Settings, configure Java SDK Path and Android SDK Path.
4. Open Project > Export, add an Android preset and select arm64-v8a.
5. Enable the Internet permission only if testing the LAN multiplayer prototype.
6. Export a debug APK, copy it to the Vivo Y17s and install it. For Play Store release, configure
   signing and export an Android App Bundle (AAB).

OFFICIAL ANDROID EXPORT GUIDE
https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

VIVO Y17S PERFORMANCE STARTING POINT
- Keep the Compatibility renderer.
- Keep shadows disabled until device profiling shows they are affordable.
- Use a modest 3D viewport scale and avoid high-poly meshes or multiple dynamic lights.
- The procedural cars batch rigid body parts by material and use MultiMesh wheels to reduce draw calls.
- Test on the actual phone; editor preview performance is not a reliable phone benchmark.

NEXT DEVELOPMENT MILESTONES
1. Add a proper lap/time-trial system, finish line, race results and rewards.
2. Add track selection and a second environment with reusable low-poly modular assets.
3. Improve driving physics, suspension, wheel animation and collision handling.
4. Replace transform-only LAN sync with synchronized spawn/state and then a dedicated online server.
5. Add optimized imported vehicle meshes only after a real-device performance test.
