# QoL
## Separating Mod Folder From Git Folder
When you upload your mod to the Avorion workshop, it automatically tries to upload the whole folder including unrelated files like the **.git** folder.  
To avoid this you have to remove all these files before uploading your mod which is tedious.  
On the other hand you could create your git repository outside of your mod folder but if you work on multiple mods they'd need to be in the same repository which convolutes the repository.
To avoid both problems you can create your repository outside your mods folder and create a ***directory junction***(Windows)/***mountpoint***(Linux) inside linking to your mod folder.

On Windows:

Given the following directories:  
- ModDir = %AppData%\Avorion\mods\YourMod  
- GitDir = ...\YourModRepository

Do the following: 
1. open cmd (you may need to open it as administrator)
2. navigate to GitDir
3. type `mklink /J FolderNameInRepo ModDir`

Notes: 
- I'd use the same folder name in your repo as the folder name of your mod, so FolderNameInRepo = YourMod
- the Linux equivalent would be `mount --bind`

i.e. with my mod at C:\Users\Sineme\AppData\Roaming\Avorion\mods\ScoutCaptainOperation I'd execute the following command (Notice the location I execute the command at)
```console
C:\Users\Sineme\Documents\GitHub\Avorion\ScoutCaptainOperation> mklink /J ScoutCaptainOperation "C:\Users\Sineme\AppData\Roaming\Avorion\mods\ScoutCaptainOperation"
```
after this your repository should look like this:

- ...\ScoutCaptainOperation\  
  - .git\
  - ScoutCaptainOperation\
    - data\
    - modinfo.lua
    - thumb.png
  - ReadMe.md
  - .gitignore
  - .gitattributes
  - ...
