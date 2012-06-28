import glob,os
for path in glob.glob("../madblocks/textures/madblocks_hydroponics*"):
    name = path[0x20:]
    os.rename(path,os.path.join("textures",name))

