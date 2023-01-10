# Godot Physics Asset Plugin

 Physics Asset plugin allows user to create Physical and Rigid bodies to different armatures and test them in runtime.

### How to work with plugin?

Install and enable plugin

![Enable Plugin](/Img/First%20Step.PNG)
   
Go to `/Addons/physics_assets/Scene/PhysicsAssets/` and look for `PhysicsAssetScene.tscn` - this is base scene for `PhysicsAsset` Editor.

![Physics Asset Scene Location](/Img/Physics%20Asset%20Scene%20Location.PNG)

Inherit a new scene from it:

![Inheriting new Scene](/Img/Inheriting%20new%20Scene.PNG)

It will open you new scene tab where you can drop custom armature (bu copy-paste) and generate physical bones for it.

![New Physics Asset Scene](/Img/New%20Physics%20Asset%20Scene.PNG)

By default scene contains only the floor. But any armature added to this scene will have custom editor on it:

![Physics Asset Editor](/Img/Physics%20Asset%20Editor.PNG)

In here you can generate phusical bones by writing custom rules.
Or you can fill rig with automatically generated bones using buttons below:

![Generating Physical Bones](/Img//Generating%20Physical%20Bones.PNG)

Just select necessary parameters and it will generate the rest.

Also you can convert list of generated bones into the rules list using `Read Pattern` button.

To simulate ragdoll in-editor use `Simulate Physical Bones` button in Utility section. There is also handy tools to work with Physical Bones.

![Simulate Ragdoll Button](/Img/Simulate%20Ragdoll%20Button.PNG)

### Extracting and using Skeleton Data

As additional functionality plugin allows to extract, combine and use sekeletal bone data from various rigs.
Why is this usefull? It's because godot dosen't have things like `Master Pose Component`. And dosen't have component-related loading at all. So everytime you update armature for your game - you'l have to re-load it by hands everywhere it is used in the project. Which is very BAD. Combined Skeleton class functionalyty allows to load, combine and update skeletons on the fly.

To extract data - select `Skeleton` node outside of PhysicsAsset scene:

![Save Rig Data Button](/Img/Save%20Rig%20Data%20Button.PNG)

You will see `Save Rig Data` button on top of the properties panel. It will popup save dialog:

![Save Rig Data Dialog](/Img/Save%20Rig%20Dta%20Dialog.PNG)

Save rig data using  this dialog.

Now you'l be able to load it into CombinedSkeleton node:

![Combined Skeleton Node](/Img/Combined%20Skeleton%20Node.PNG)

Add it to scene and you'l see this parameters:

![Combined Skeleton Parameters](/Img/Combined%20Skeleton%20Parameters.PNG)

Just increase Size to 1 and pick up rig dta You saved previously.

![Load Rig Data](/Img/Load%20Rig%20Data.PNG)

Then just press to `Build` and it will load the rig.

![Loaded Rig](/Img/Loaded%20Rig.PNG)