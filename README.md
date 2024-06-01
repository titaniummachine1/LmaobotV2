## LMAOBox-Navbot
**Pathfinding and Navigation Bot for LMAOBox Lua**

### Status
*Currently: Not Functional. Awaiting LMAOBox Lua update for debugging.*

### Requirements
- **LnxLib**: [Download from GitHub](https://github.com/lnx00/Lmaobox-Library/releases/latest)

### Usage Instructions

1. **Download Lmaobot.lua**
   - Go to releases and download the `Lmaobot.lua` script to your `%localappdata%` folder.

2. **Prepare Nav Meshes**
   - If you don't have nav meshes, download `MakeNavs.bat` from the source code and run it.

3. **Start TF2 and Inject LMAOBox**
   - Launch TF2.
   - Inject LMAOBox.
   - Join a CTF, PL, or PLR map (currently supports these game modes).

4. **Load Lmaobot.lua**
   - Go to the Lua tab in the LMAOBox menu.
   - Load `Lmaobot.lua`.

5. **Enjoy NavBot on LMAOBox!**

### For Developers: How to Compile/Bundle

1. **Install Node.js**
   - Download and install the stable version of [Node.js](https://nodejs.org/).

2. **Download Source Code**
   - Go to releases and download the source code (zip).
   - Unzip it to any desired location.

3. **Install LuaBundle**
   - Open the **Node.js command prompt**.
   - Execute: `npm install luabundle`.

4. **Run Batch Scripts**
   - Run `Bundle.bat` and wait for it to finish.
   - Run `BundleAndDeploy.bat`.

5. **Generate Nav Meshes**
   - Run `MakeNavs.bat` to create nav meshes for all casual maps.

6. **Start TF2 and Inject LMAOBox**
   - Launch TF2.
   - Inject LMAOBox (ensure it's not the beta build).
   - Join a map.

7. **Load Lmaobot.lua**
   - Go to the Lua tab in the LMAOBox menu.
   - Load `Lmaobot.lua`.

8. **Enjoy NavBot on LMAOBox!**

### Credits
- **Original Code**: Inx00
- **Update**: titaniummachine1

For support, visit: [Discord](https://dsc.gg/rosnehook)
