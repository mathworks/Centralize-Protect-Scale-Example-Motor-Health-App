Introduction

This ReadMe describes how to install and use the example code for the 
MATLAB Digest Article, "Centralize, Protect, and Scale Your Algorithms 
with MATLAB Client for MATLAB Production Server". 

The example consists of three parts:

1. A set of source files you need to build into a deployable CTF archive, 
   which needs to be installed on MATLAB Production Server.
2. A MATLAB App, "MotorHealth", which runs in desktop MATLAB, R2020b
   or later.
3. A set of data files to be processed by the MotorHealth App.

In order to run the MotorHealth App, you'll need access to a MATLAB 
desktop, and an instance of MATLAB Production Server. In order to create
the deployable archive, you'll need MATLAB Compiler SDK.

Process Overview

Perform these steps in this order:

1. Start a persistence service (Redis) for your MATLAB Production Server.
2. Install MATLAB Client for MATLAB Production Server.
3. Deploy the MotorAnalytics archive to your MATLAB Production Server.
4. Install a MATLAB Production Server Add-On from the MotorAnalytics archive.

Start Persistence Service for MATLAB Production Server 

The Motor Health App assumes that your MATLAB Production Server instance 
is attached to a Redis server named "LocalRedis". Use the MATLAB Production
Server dashboard to start and attach a persistence connection named 
LocalRedis to your MATLAB Production Server instance. See the MATLAB
Production Server data cache documentation for more details.

Install MATLAB Client for MATLAB Production Server

1. Locate the "Environment" tab in the MATLAB toolstrip.
2. In the Add-Ons section, click "Get Add-Ons". A separate window will open.
3. In the search bar at the top of the new window, type "MATLAB Client for
   MATLAB Production Server" (without the quotes).
4. Press the Return key, or click the magnifying glass icon to search.
5. Click "MATLAB Client for MATLAB Production Server" (the title) in the
   search results. 
6. Click the blue button to the right: "Add"

Build the Deployable Archive

1. Open the MotorAnalytics.prj project file from the Server folder.
2. Click the "Package" button.

Deploy the MotorAnalytics Archive to your MATLAB Production Server

1. Locate the "Server" folder, which should be adjacent to this ReadMe file.
2. Deploy the MotorAnalytics archive,
   Server/MotorAnalytics/for_redistribution/MotorAnalytics.ctf to your 
   instance of MATLAB Production Server, following the instructions in 
   Server/readme.txt.
   
Install MotorAnalytics Add-On 

1. Determine the network address of your MATLAB Production Server. For 
   example, the default, "localhost:9910".
2. Use the prodserver.addon.install command in MATLAB:
   >> prodserver.addon.install('MotorHealth','localhost',9910)
   If you need assistance:
   >> help prodserver.addon.install
   
Run MotorHealth
 
1. Start MATLAB R2020b or higher. 
2. Set the current directory to the Client directory below this ReadMe file.
   >> cd Client
3. Start the MotorHealth client.
   >> MotorHealth
4. Select the Data folder with the "Motor Data Folder..." button.
5. Choose a motor data set to visualize -- motors 3, 5, and 8 show interesting 
   remaining useful life curves.
6. Press the "Visualize" button.




   
 