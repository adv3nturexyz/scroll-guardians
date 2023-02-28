// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// NFT contract to inherit from
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Helper functions OpenZeppelin provides
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Helper to encode in Base64
import "./libraries/Base64.sol";

import "hardhat/console.sol";

contract BufficornBattle is ERC721 {

  struct CharacterAttributes {
    uint characterIndex;
    string name;
    string imageURI;        
    uint hp;
    uint maxHp;
    uint attackDamage;
  }

  function heal() public {
    uint tokenId = nftHolders[msg.sender];
    CharacterAttributes storage charAttributes = nftHolderAttributes[tokenId];
    require(msg.sender == ownerOf(tokenId), "You must own this NFT to heal the character!");
    require(charAttributes.maxHp > charAttributes.hp, "Your character already has full HP!");
    require(pointsBalance[msg.sender] >= 30, "Not enough points to heal. Attack at least 3 times first.");
    pointsBalance[msg.sender] -= 30;
    charAttributes.hp = charAttributes.maxHp;
  }

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  CharacterAttributes[] defaultCharacters;

  mapping(uint256 => CharacterAttributes) public nftHolderAttributes;
  mapping(address => uint256) public nftHolders;
  mapping(address => uint256) public pointsBalance;

  event CharacterNFTMinted(address sender, uint256 tokenId, uint256 characterIndex);
  event AttackComplete(address sender, uint newBossHp, uint newPlayerHp);

  // Build a basic boss struct and initialize its data.
  struct BigBoss {
    string name;
    string imageURI;
    uint hp;
    uint maxHp;
    uint attackDamage;
  }

  BigBoss public bigBoss;

  constructor(
    string[] memory characterNames,
    string[] memory characterImageURIs,
    uint[] memory characterHp,
    uint[] memory characterAttackDmg,

    string memory bossName, // These new variables would be passed in via run.js or deploy.js.
    string memory bossImageURI,
    uint bossHp,
    uint bossAttackDamage
  )
    ERC721("Bufficorn Battle", "BUFFICORN")
  {
    // Initialize the boss. Save it to global "bigBoss" state variable.
    bigBoss = BigBoss({
      name: bossName,
      imageURI: bossImageURI,
      hp: bossHp,
      maxHp: bossHp,
      attackDamage: bossAttackDamage
    });

    console.log("Done initializing boss %s w/ HP %s, img %s", bigBoss.name, bigBoss.hp, bigBoss.imageURI);

    // Initialize the player.
    for(uint i = 0; i < characterNames.length; i += 1) {
      defaultCharacters.push(CharacterAttributes({
        characterIndex: i,
        name: characterNames[i],
        imageURI: characterImageURIs[i],
        hp: characterHp[i],
        maxHp: characterHp[i],
        attackDamage: characterAttackDmg[i]
      }));

      CharacterAttributes memory c = defaultCharacters[i];
      
      // Hardhat's use of console.log() allows up to 4 parameters in any order of following types: uint, string, bool, address
      console.log("Done initializing %s w/ HP %s, img %s", c.name, c.hp, c.imageURI);
    }

    _tokenIds.increment();
  }

  // For users to get their NFT based on the characterId they send in.
  function mintCharacterNFT(uint _characterIndex) external {
    // Get current tokenId (starts at 1 since we incremented in the constructor).
    uint256 newItemId = _tokenIds.current();

    // Assigns the tokenId to the caller's wallet address.
    _safeMint(msg.sender, newItemId);

    // Map the tokenId => their character attributes. 
    nftHolderAttributes[newItemId] = CharacterAttributes({
      characterIndex: _characterIndex,
      name: defaultCharacters[_characterIndex].name,
      imageURI: defaultCharacters[_characterIndex].imageURI,
      hp: defaultCharacters[_characterIndex].hp,
      maxHp: defaultCharacters[_characterIndex].maxHp,
      attackDamage: defaultCharacters[_characterIndex].attackDamage
    });

    console.log("Minted NFT w/ tokenId %s and characterIndex %s", newItemId, _characterIndex);
    
    // Keep an easy way to see who owns what NFT.
    nftHolders[msg.sender] = newItemId;

    // Increment the tokenId for the next person that uses it.
    _tokenIds.increment();

    emit CharacterNFTMinted(msg.sender, newItemId, _characterIndex);
  }

  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    CharacterAttributes memory charAttributes = nftHolderAttributes[_tokenId];

    string memory strHp = Strings.toString(charAttributes.hp);
    string memory strMaxHp = Strings.toString(charAttributes.maxHp);
    string memory strAttackDamage = Strings.toString(charAttributes.attackDamage);

    string memory json = Base64.encode(
      bytes(
        string(
        abi.encodePacked(
        '{"name": "',
        charAttributes.name,
        ' - Bufficorn #',
        Strings.toString(_tokenId),
        '", "description": "This is an NFT that lets people play in the game Bufficorn Battle by Adv3nture.xyz.", "image": "ipfs://',
        charAttributes.imageURI,
        '", "attributes": [ { "trait_type": "Health Points", "value": ',strHp,', "max_value":',strMaxHp,'}, { "trait_type": "Attack Damage", "value": ',
        strAttackDamage,'} ]}'
        )
      ))
    );

    string memory output = string(
        abi.encodePacked("data:application/json;base64,", json)
    );
    
    return output;
  }

  function attackBoss() public {
    // Get the state of the player's NFT.
    uint256 nftTokenIdOfPlayer = nftHolders[msg.sender];
    CharacterAttributes storage player = nftHolderAttributes[nftTokenIdOfPlayer];

    console.log("\nPlayer w/ character %s about to attack. Has %s HP and %s AD", player.name, player.hp, player.attackDamage);
    console.log("Boss %s has %s HP and %s AD", bigBoss.name, bigBoss.hp, bigBoss.attackDamage);
    
    // Make sure the player has more than 0 HP.
    require (
      player.hp > 0,
      "Error: character must have HP to attack boss."
    );

    // Make sure the boss has more than 0 HP.
    require (
      bigBoss.hp > 0,
      "Error: boss must have HP to attack character."
    );
    
    // Allow player to attack boss.
    if (bigBoss.hp < player.attackDamage) {
      bigBoss.hp = 0;
    // attack logic:
    } else {
      bigBoss.hp = bigBoss.hp - player.attackDamage;
      // whenever player attacks, increase their points balance by 10
      pointsBalance[msg.sender] += 10;
    }        

    // Allow boss to attack player.
    if (player.hp < bigBoss.attackDamage) {
      player.hp = 0;
    // attack logic:
    } else {
      if (randomInt(10) < 7) { // returns 0-9: 20% chance to evade attack
        player.hp = player.hp - bigBoss.attackDamage;
        console.log("%s attacked player. New player hp: %s", bigBoss.name, player.hp);
      } else {
        console.log("%s missed!\n", bigBoss.name);
      }
    }    
    
    // Console for ease.
    console.log("Player attacked boss. New boss hp: %s", bigBoss.hp);
    console.log("Boss attacked player. New player hp: %s\n", player.hp);

    emit AttackComplete(msg.sender, bigBoss.hp, player.hp);
  }

  uint randNonce = 0; // this is used to help ensure that the algorithm has different inputs every time

  function randomInt(uint _modulus) internal returns(uint) {
    randNonce++;                                                     // increase nonce
    return uint(keccak256(abi.encodePacked(block.timestamp,          // 'now' has been deprecated, use 'block.timestamp' instead
                                          msg.sender,               // your address
                                          randNonce))) % _modulus;  // modulo using the _modulus argument
  }

  function checkIfUserHasNFT() public view returns (CharacterAttributes memory) {
    // Get the tokenId of the user's character NFT
    uint256 userNftTokenId = nftHolders[msg.sender];
    // If the user has a tokenId in the map, return their character.
    if (userNftTokenId > 0) {
      return nftHolderAttributes[userNftTokenId];
    }
    // Else, return an empty character.
    else {
      CharacterAttributes memory emptyStruct;
      return emptyStruct;
    }
  }

  function getAllDefaultCharacters() public view returns (CharacterAttributes[] memory) {
    return defaultCharacters;
  }

  function getBigBoss() public view returns (BigBoss memory) {
    return bigBoss;
  }

}