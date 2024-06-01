## LMAOBox-Navbot
**Pathfinding and Navigation Bot for LMAOBox Lua**

### Requirements
- **!!! IMPORTANT !!!** You **MUST** have **LnxLib** installed for this to work! 
- **[Download LnxLib from GitHub](https://github.com/lnx00/Lmaobox-Library/releases/latest)**
  
  ![LnxLib Required](https://dummyimage.com/600x200/ff0000/ffffff&text=**YOU+MUST+HAVE+LNXLIB+INSTALLED!**)

### Status
*Currently: Not Functional. Awaiting LMAOBox Lua update for debugging.*

![LMAOBox Navbot](https://cdn.discordapp.com/attachments/1200832181547847750/1210581139346030703/306752016-fdfc25e6-766d-4088-ab1a-21d99a5c2d8b.png?ex=665c758b&is=665b240b&hm=98309ad6691c7ab57c3e0c708e9d949cb00e63b17ef1705f7ae04fd7c20f941f&)

### Usage Instructions

1. **Download Lmaobot.lua**
   - Go to releases and download the `Lmaobot.lua` script to your `%localappdata%` folder.

2. **Prepare Nav Meshes**
   - If you don't have nav meshes, download `MakeNavs.bat` from the source code and run it.
   - **Finding Game Maps Directory**:
     - Navigate to your TF2 installation directory. This is usually found at `C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\maps`.
   - **Using MakeNavs.bat**:
     - Open the command prompt and navigate to the directory where you downloaded `MakeNavs.bat`.
     - Execute `MakeNavs.bat`.
     - When prompted, paste the path to your TF2 maps directory (`C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\maps`).
     - Alternatively, you can drag and drop all generated nav meshes into the `maps` folder.

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
   - **Finding Game Maps Directory**:
     - Navigate to your TF2 installation directory. This is usually found at `C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\maps`.
   - **Using MakeNavs.bat**:
     - Open the command prompt and navigate to the directory where you downloaded `MakeNavs.bat`.
     - Execute `MakeNavs.bat`.
     - When prompted, paste the path to your TF2 maps directory (`C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\maps`).
     - Alternatively, you can drag and drop all generated nav meshes into the `maps` folder.

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
