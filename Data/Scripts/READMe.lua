--[[
	The NFT Picture Frame will load the player's wallet and allow them to drag their NFT
	images onto the frames in the world. This will work in multiplayer as well.

	1. Drag the NFT Picture Frame System into the Hierarchy.
	2. Add as many Picture Frame template to the folder Picture Frames.
	3. Create a concurrent creator key and add it to the "CreatorStorageKey" property. (OPTIONAL)
	4. Enter play mode and wait for the NFTs to load into the inventory (I or E to open and close).
	5. Get a picture frame into view (outline will show the active one).
	6. Click the NFT from the inventory, then click on the frame.

	If you would prefer to load a specific collection of NFTs for all players to use, then there is
	a property on the NFT Picture Frame System where you can set the contract address. This will 
	override player wallets.
--]]